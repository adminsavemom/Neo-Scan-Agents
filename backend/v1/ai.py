"""
python ai.py
v1/ai.py

AI utility — Ollama-based Vision analysis for the V3 neonatal video analyzer.

This module sends extracted video frames to a local Ollama model and returns
a validated JSON response matching the BabyVideoAnalysis schema — the full
clinical assessment with Kramer zones, Silverman-Andersen, NIPS, NBAS,
Prechtl, IMNCI danger signs, and seizure differentiation.

Model selection strategy (local-first):
  1. Scan output/ directory for a Baby Gemma GGUF file (e.g. BabyGemma.gguf).
  2. If found → register it with Ollama and use it.
  3. If not found → fall back to the default gemma4:e2b model via Ollama.

Key design decisions:
- The prompt includes validated clinical scale references for grounded scoring.
- Unknown/unobservable values must be null, not guessed.
- The response is validated against the Pydantic schema before return.
- All inference is fully local; no cloud API keys are required.
"""

from __future__ import annotations

import base64
import glob
import json
import logging
import os
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from fastapi import HTTPException

from v1.schema import BabyVideoAnalysis, JaundiceBreathingAnalysis

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model selection — performed once at import time
# ---------------------------------------------------------------------------

_OUTPUT_DIR = Path(__file__).resolve().parent.parent / "output"

# Pattern that identifies a Baby-Gemma GGUF file in the output/ folder.
_BABY_GEMMA_GLOB = "*.gguf"
_FALLBACK_MODEL = "gemma4:e2b"

# Ollama model tag that will be used throughout the module.
_ACTIVE_MODEL: str = _FALLBACK_MODEL
_CUSTOM_MODEL_TAG: str | None = None  # set when a GGUF is loaded


def _find_baby_gemma_gguf() -> Path | None:
    """
    Scan the output/ directory for any GGUF file.
    Returns the first match (case-insensitive), or None if not found.
    """
    if not _OUTPUT_DIR.exists():
        logger.warning("output/ directory not found at %s", _OUTPUT_DIR)
        return None

    matches = sorted(_OUTPUT_DIR.glob(_BABY_GEMMA_GLOB))
    if matches:
        logger.info("Found local GGUF model: %s", matches[0])
        return matches[0]
    return None


def _register_gguf_with_ollama(gguf_path: Path) -> str:
    """
    Register a local GGUF file as a named Ollama model via a temporary
    Modelfile, then return the model tag.

    The tag is derived from the file stem: e.g. BabyGemma.gguf → babygemma.
    """
    tag = gguf_path.stem.lower().replace(" ", "_")

    # Write a minimal Modelfile
    modelfile_content = f'FROM "{gguf_path.as_posix()}"\n'
    modelfile_path = _OUTPUT_DIR / "Modelfile"
    modelfile_path.write_text(modelfile_content, encoding="utf-8")

    logger.info("Registering GGUF model '%s' with Ollama…", tag)
    try:
        result = subprocess.run(
            ["ollama", "create", tag, "-f", str(modelfile_path)],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"ollama create failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
            )
        logger.info("Model '%s' registered successfully.", tag)
    except FileNotFoundError as exc:
        raise RuntimeError(
            "Ollama CLI not found. Ensure Ollama is installed and on PATH."
        ) from exc
    finally:
        # Clean up temp Modelfile
        if modelfile_path.exists():
            modelfile_path.unlink()

    return tag


def _select_model() -> tuple[str, bool]:
    """
    Determine which Ollama model to use.

    Returns
    -------
    (model_tag, is_custom) where is_custom=True when a local GGUF was loaded.
    """
    gguf = _find_baby_gemma_gguf()
    if gguf:
        try:
            tag = _register_gguf_with_ollama(gguf)
            logger.info("Active model: %s (local GGUF)", tag)
            return tag, True
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Failed to load local GGUF (%s). Falling back to %s. Error: %s",
                gguf.name,
                _FALLBACK_MODEL,
                exc,
            )

    logger.info("Active model: %s (Ollama default)", _FALLBACK_MODEL)
    return _FALLBACK_MODEL, False


# Run model selection at module load time.
_ACTIVE_MODEL, _CUSTOM_MODEL_TAG = _select_model()  # type: ignore[assignment]


# ---------------------------------------------------------------------------
# Ollama chat helper
# ---------------------------------------------------------------------------

def _ollama_chat(
    prompt: str,
    images: list[bytes] | None = None,
    max_retries: int = 2,
) -> str:
    """
    Call the local Ollama model and return the response string.

    Parameters
    ----------
    prompt : str
        Text prompt to send.
    images : list[bytes] | None
        Raw image bytes to attach (multimodal).
    max_retries : int
        Number of retry attempts on transient failures.
    """
    try:
        from ollama import chat as ollama_chat  # lazy import
    except ImportError as exc:
        raise RuntimeError(
            "The 'ollama' Python package is not installed. "
            "Run: pip install ollama"
        ) from exc

    message: dict[str, Any] = {"role": "user", "content": prompt}
    if images:
        message["images"] = images

    last_error: Exception | None = None
    for attempt in range(1, max_retries + 1):
        try:
            response = ollama_chat(
                model=_ACTIVE_MODEL,
                messages=[message],
                options={
                    "temperature": 0.1,
                    "top_p": 0.9,
                    "seed": 42,
                },
            )
            return response.message.content
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            logger.warning(
                "Ollama call failed (attempt %d/%d): %s",
                attempt,
                max_retries,
                exc,
            )
            if attempt < max_retries:
                time.sleep(1.5 * attempt)

    raise RuntimeError(
        f"Ollama inference failed after {max_retries} attempts: {last_error}"
    )


# ---------------------------------------------------------------------------
# Frame utilities
# ---------------------------------------------------------------------------

def _frame_to_jpeg_bytes(frame: np.ndarray) -> bytes:
    """Encode an OpenCV BGR frame to raw JPEG bytes."""
    _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
    return buf.tobytes()


def _sample_frames(frames: list[np.ndarray], max_frames: int = 8) -> list[np.ndarray]:
    """Return up to *max_frames* evenly-spaced frames from *frames*."""
    n = len(frames)
    if n <= max_frames:
        return frames
    indices = [int(i * (n - 1) / (max_frames - 1)) for i in range(max_frames)]
    return [frames[i] for i in indices]


# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

def _build_prompt(
    has_audio: bool = False,
    audio_context: dict[str, Any] | None = None,
) -> str:
    """
    Build the analysis prompt with full clinical scale references and the
    BabyVideoAnalysis JSON schema.
    """
    schema_json = json.dumps(BabyVideoAnalysis.model_json_schema(), indent=2)

    audio_section = ""
    if has_audio and audio_context:
        audio_json = json.dumps(audio_context, indent=2)
        audio_section = f"""
AUDIO CONTEXT (pre-extracted features):
{audio_json}
Use these audio features to assess cry detection and expiratory grunt scoring.
If audio features indicate no significant energy or amplitude, set cry-related
fields accordingly.
"""

    return f"""
SYSTEM ROLE:
You are a Clinical Computer Vision Diagnostic Engine specialized in neonatal
intensive care (NICU). You analyze video frames of neonates and extract
structured, medically validated physiological and behavioral data. Your output
populates a live clinical monitoring dashboard and is stored directly into a
database. Every field you output must conform to the exact JSON schema below.

CRITICAL RULES:
1. DO NOT invent arbitrary 0–100 scores. All values must map to validated
   clinical scales.
2. If a parameter CANNOT be assessed (occlusion, lighting, angle), set its
   value to null and add an entry to "assessment_limitations".
3. DO NOT provide a diagnosis. Report observations and flag escalations.
4. Analyze the FULL video duration. Base all scores on the most consistent
   observable window.
5. All timestamps use ISO 8601 format.
6. Output ONLY the JSON object — no prose, no explanation, no markdown fences.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CLINICAL SCALE REFERENCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[SCALE A] KRAMER JAUNDICE ZONES
Zone 1 → Face & neck only            → Estimated TSB: 5–9 mg/dL
Zone 2 → Chest & upper abdomen       → Estimated TSB: 7–11 mg/dL
Zone 3 → Lower abdomen & thighs      → Estimated TSB: 9–13 mg/dL  ← Phototherapy threshold
Zone 4 → Arms & lower legs           → Estimated TSB: 11–16 mg/dL ← HIGH RISK
Zone 5 → Palms & soles               → Estimated TSB: >15 mg/dL   ← CRITICAL
Depth: "lemon_yellow" = mild; "deep_orange" = pathological
Auto-flag: kramer_alert = true if zone >= 3
Auto-flag: critical_hyperbilirubinemia = true if zone >= 4

[SCALE B] DERMAL LESION CLASSIFICATION
petechiae  → Non-blanching, < 2 mm
purpura    → Non-blanching, > 2 mm
ecchymosis → Bruising, >1 cm
Blueberry Muffin Pattern → Multifocal blue-purple nodular lesions
Auto-flag: lesion_alert = true if purpura or blueberry_muffin_pattern detected

[SCALE C] SILVERMAN-ANDERSEN RESPIRATORY SEVERITY SCORE (0–10 total)
Each of 5 parameters scored 0, 1, or 2:
upper_chest_movement: 0=sync 1=lagging 2=see-saw
lower_chest_retractions: 0=none 1=mild 2=marked
xiphoid_retraction: 0=none 1=mild 2=marked
nasal_flaring: 0=none 1=minimal 2=marked
expiratory_grunt: 0=none 1=stethoscope only 2=audible (requires audio; null if no audio)
Total: 0=no distress 1-3=mild 4-6=moderate(flag) 7-10=severe(critical)
Tachypnea: RR > 60 bpm → tachypnea_alert = true
Apnea: cessation > 15s → apnea_alert = true
Bradypnea: RR < 30 bpm → bradypnea_alert = true

[SCALE D] NEONATAL INFANT PAIN SCALE — NIPS (0–7 total)
facial_expression: 0=relaxed 1=grimace
cry: 0=none 1=whimper 2=vigorous
breathing_pattern: 0=relaxed 1=irregular/gasping
arms: 0=relaxed 1=flexed/rigid
legs: 0=relaxed 1=flexed/rigid
state_of_arousal: 0=sleeping/peaceful 1=fussy/agitated
Total: 0-2=comfortable 3-4=mild(flag) 5-7=significant(critical)

[SCALE E] NBAS CONSCIOUSNESS STATE
1=Deep Sleep 2=Active Sleep 3=Drowsy 4=Quiet Alert 5=Active Alert 6=Crying

[SCALE F] PRECHTL GENERAL MOVEMENT ASSESSMENT
normal_complexity / poor_repertoire / cramped_synchronized / absent

[SCALE G] IMNCI DANGER SIGNS (any single = CRITICAL)
- Extreme lethargy / unconsciousness
- Severe chest indrawing (Silverman-Andersen >= 7)
- Sustained RR > 60 bpm
- Central cyanosis
- Convulsions / seizure
- Inability to feed

[SCALE H] SEIZURE vs JITTERINESS
Seizure (seizure_risk = "HIGH"):
  rhythmic clonic jerking with fast+slow phases, cannot be stopped by holding,
  ocular deviation, concurrent apnea/cyanosis, lip smacking
Jitteriness (jitteriness_risk = "LOW"):
  rapid symmetric tremors, stops when limb held, stimulus-triggered,
  no abnormal ocular movements, no apnea

{audio_section}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT SCHEMA — Produce EXACTLY this JSON structure
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{schema_json}

Clinical reference thresholds (AAP / WHO):
- Normal neonatal RR: 40–60 bpm
- Bradypnea: <30 | Tachypnea: >60 | Critical: <20 or >80 bpm
- yellow_index: flag if > 0.25
- blue_index: flag if > 0.15
- symmetry_score < 0.65 → possible asymmetry
- activity_score < 0.06 without cry → low_activity

VALIDATION RULES:
- Output must be valid parseable JSON
- No trailing commas, no markdown, no extra keys beyond schema
- If uncertain, prefer null
- Return ONLY the JSON object. No other text.
"""


def _build_jaundice_breathing_prompt() -> str:
    schema_json = json.dumps(JaundiceBreathingAnalysis.model_json_schema(), indent=2)
    return f"""
Analyze the baby video carefully.

Only detect:
1. Possible jaundice based on visible yellow skin coloration
2. Possible breathing issue based on chest movement

Rules:
- Do not hallucinate
- Do not guess hidden information
- Only use visible evidence from the video
- If visibility is poor, return unclear or null
- Output STRICT VALID JSON only
- No explanation text, no markdown, no extra fields

Jaundice:
- Detect visible yellow skin tone only
- Estimate yellowing zone: face / chest / abdomen / full_body / none / unclear

Breathing:
- Observe chest movement only
- Detect: normal / shallow / irregular / not_visible
- If breathing cannot be measured: estimated_breathing_rate = null,
  breathing_risk = unknown

Confidence: 0.0 to 1.0 (lower if video quality is poor)

Return JSON matching exactly this schema:
{schema_json}

Validation Rules:
- Return valid JSON only
- No trailing commas, no comments, no markdown
- Confidence must be 0.0 to 1.0
- Use null if uncertain
- Use limitations[] for poor visibility
"""


# ---------------------------------------------------------------------------
# JSON extraction helper
# ---------------------------------------------------------------------------

def _extract_json(raw: str) -> dict[str, Any]:
    """
    Strip any accidental markdown fences and parse the JSON object from *raw*.
    Raises ValueError on failure.
    """
    text = raw.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)

    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"Model returned non-JSON output: {text[:500]}"
        ) from exc


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

async def analyze_video_with_ai(
    frames: list[np.ndarray],
    has_audio: bool = False,
    audio_context: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    Send extracted video frames to the local Ollama model and return a
    validated BabyVideoAnalysis dict.

    Parameters
    ----------
    frames : list[np.ndarray]
        Sampled BGR frames extracted from the video (OpenCV format).
    has_audio : bool
        Whether audio was available in the uploaded video.
    audio_context : dict | None
        Pre-extracted audio features used as additional context for
        cry/distress detection.

    Returns
    -------
    dict
        Validated response matching BabyVideoAnalysis schema.
    """
    if not frames:
        raise HTTPException(
            status_code=422,
            detail="No video frames provided for analysis.",
        )

    try:
        t_start = time.perf_counter()

        sampled = _sample_frames(frames, max_frames=8)
        image_bytes = [_frame_to_jpeg_bytes(f) for f in sampled]

        prompt = _build_prompt(has_audio=has_audio, audio_context=audio_context)

        raw_text = _ollama_chat(prompt, images=image_bytes)
        logger.info("Raw response from Ollama: %s", raw_text)

        result = _extract_json(raw_text)

        # Ensure session_metadata timestamp
        result.setdefault("session_metadata", {})
        if not result["session_metadata"].get("analysis_timestamp"):
            result["session_metadata"]["analysis_timestamp"] = (
                datetime.now(timezone.utc).isoformat()
            )

        validated = BabyVideoAnalysis.model_validate(result)

        logger.info(
            "analyze_video_with_ai completed in %.3fs using model '%s'",
            time.perf_counter() - t_start,
            _ACTIVE_MODEL,
        )

        return validated.model_dump(mode="json")

    except HTTPException:
        raise
    except ValueError as ve:
        raise HTTPException(status_code=422, detail=str(ve)) from ve
    except RuntimeError as re_:
        raise HTTPException(
            status_code=503,
            detail=f"Ollama service error: {re_}",
        ) from re_
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"AI analysis failed: {exc}",
        ) from exc


async def analyze_jaundice_breathing_with_ai(
    frames: list[np.ndarray],
) -> dict[str, Any]:
    """
    Lightweight jaundice + breathing analysis using the local Ollama model.

    Parameters
    ----------
    frames : list[np.ndarray]
        Sampled BGR frames extracted from the video.

    Returns
    -------
    dict
        Validated response matching JaundiceBreathingAnalysis schema.
    """
    if not frames:
        raise HTTPException(
            status_code=422,
            detail="No video frames provided.",
        )

    try:
        t_start = time.perf_counter()

        sampled = _sample_frames(frames, max_frames=8)
        image_bytes = [_frame_to_jpeg_bytes(f) for f in sampled]

        prompt = _build_jaundice_breathing_prompt()
        raw_text = _ollama_chat(prompt, images=image_bytes)

        result = _extract_json(raw_text)

        if not result.get("timestamp_utc"):
            result["timestamp_utc"] = datetime.now(timezone.utc).isoformat()
        if not result.get("analysis_status"):
            result["analysis_status"] = "success"

        validated = JaundiceBreathingAnalysis.model_validate(result)

        logger.info(
            "analyze_jaundice_breathing_with_ai completed in %.3fs using model '%s'",
            time.perf_counter() - t_start,
            _ACTIVE_MODEL,
        )

        return validated.model_dump(mode="json")

    except HTTPException:
        raise
    except ValueError as ve:
        raise HTTPException(status_code=422, detail=str(ve)) from ve
    except RuntimeError as re_:
        raise HTTPException(
            status_code=503,
            detail=f"Ollama service error: {re_}",
        ) from re_
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"AI analysis failed: {exc}",
        ) from exc