"""
v1/ai.py

AI utility — Staged Ollama/Gemma-4 pipeline for the neonatal video analyzer.

WHY STAGED?
  Gemma 4 running locally via Ollama has a limited effective context window
  and cannot reliably produce 100+ structured fields in a single pass.
  Sending 8 frames + a 4 000-token prompt produces almost all nulls.

  Solution: run 3 small, focused inference steps on 1 carefully chosen
  frame each, then merge the responses into the full BabyVideoAnalysis schema.

  Pipeline
  ────────
  Stage 1 — Frame quality gate      (pure CV, no model call)
  Stage 2 — Skin / jaundice / color (1 best-skin frame)
  Stage 3 — Respiratory effort       (1 chest frame)
  Stage 4 — Movement / neurology     (1 body frame)
  Stage 5 — Programmatic merge + Pydantic validation

Model selection (local-first)
  1. Scan output/ for *.gguf → register with Ollama and use it.
  2. Fallback: gemma4:e2b via Ollama.
"""

from __future__ import annotations

import json
import logging
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

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Model selection
# ─────────────────────────────────────────────────────────────────────────────

_OUTPUT_DIR = Path(__file__).resolve().parent.parent / "output"
_FALLBACK_MODEL = "gemma4:e2b"


def _find_gguf() -> Path | None:
    if not _OUTPUT_DIR.exists():
        return None
    matches = sorted(_OUTPUT_DIR.glob("*.gguf"))
    return matches[0] if matches else None


def _register_gguf(gguf: Path) -> str:
    tag = gguf.stem.lower().replace(" ", "_")
    mf = _OUTPUT_DIR / "Modelfile"
    mf.write_text(f'FROM "{gguf.as_posix()}"\n', encoding="utf-8")
    try:
        r = subprocess.run(
            ["ollama", "create", tag, "-f", str(mf)],
            capture_output=True, text=True, timeout=180,
        )
        if r.returncode != 0:
            raise RuntimeError(r.stderr)
    except FileNotFoundError as exc:
        raise RuntimeError("Ollama CLI not found on PATH.") from exc
    finally:
        mf.unlink(missing_ok=True)
    logger.info("Registered GGUF model '%s'", tag)
    return tag


def _select_model() -> str:
    gguf = _find_gguf()
    if gguf:
        try:
            return _register_gguf(gguf)
        except Exception as exc:
            logger.warning("GGUF load failed (%s); using fallback. %s", gguf.name, exc)
    logger.info("Using fallback model: %s", _FALLBACK_MODEL)
    return _FALLBACK_MODEL


_ACTIVE_MODEL: str = _select_model()

# ─────────────────────────────────────────────────────────────────────────────
# Low-level Ollama call
# ─────────────────────────────────────────────────────────────────────────────

def _chat(prompt: str, images: list[bytes] | None = None, retries: int = 3) -> str:
    """Call Ollama with retry + exponential back-off. Returns raw model text."""
    try:
        from ollama import chat as _oc
    except ImportError as exc:
        raise RuntimeError("Run: pip install ollama") from exc

    msg: dict[str, Any] = {"role": "user", "content": prompt}
    if images:
        msg["images"] = images

    last: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            resp = _oc(
                model=_ACTIVE_MODEL,
                messages=[msg],
                options={"temperature": 0.05, "top_p": 0.85, "seed": 7},
            )
            return resp.message.content
        except Exception as exc:
            last = exc
            logger.warning("Ollama attempt %d/%d: %s", attempt, retries, exc)
            if attempt < retries:
                time.sleep(1.5 * attempt)

    raise RuntimeError(f"Ollama failed after {retries} attempts: {last}")


# ─────────────────────────────────────────────────────────────────────────────
# Frame utilities
# ─────────────────────────────────────────────────────────────────────────────

def _to_jpeg(frame: np.ndarray, quality: int = 82) -> bytes:
    _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, quality])
    return buf.tobytes()


def _brightness(frame: np.ndarray) -> float:
    return float(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY).mean())


def _blur_score(frame: np.ndarray) -> float:
    return float(cv2.Laplacian(
        cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), cv2.CV_64F
    ).var())


def _resize(frame: np.ndarray, max_dim: int = 512) -> np.ndarray:
    h, w = frame.shape[:2]
    if max(h, w) <= max_dim:
        return frame
    s = max_dim / max(h, w)
    return cv2.resize(frame, (int(w * s), int(h * s)), interpolation=cv2.INTER_AREA)


def _enhance(frame: np.ndarray) -> np.ndarray:
    """Mild CLAHE brightness/contrast normalisation."""
    lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return cv2.cvtColor(cv2.merge([clahe.apply(l), a, b]), cv2.COLOR_LAB2BGR)


def _quality_filter(
    frames: list[np.ndarray],
    min_brightness: float = 30.0,
    min_blur: float = 60.0,
) -> list[np.ndarray]:
    good = [f for f in frames
            if _brightness(f) >= min_brightness and _blur_score(f) >= min_blur]
    logger.info("Quality filter: %d/%d frames kept", len(good), len(frames))
    return good or frames   # never return empty


def _deduplicate(frames: list[np.ndarray], threshold: float = 0.92) -> list[np.ndarray]:
    if len(frames) <= 1:
        return frames

    def hist(f: np.ndarray) -> np.ndarray:
        h = cv2.calcHist([f], [0, 1, 2], None, [16, 16, 16],
                         [0, 256, 0, 256, 0, 256])
        cv2.normalize(h, h)
        return h

    kept = [frames[0]]
    prev_h = hist(frames[0])
    for f in frames[1:]:
        h = hist(f)
        if cv2.compareHist(prev_h, h, cv2.HISTCMP_CORREL) < threshold:
            kept.append(f)
            prev_h = h

    logger.info("Dedup: %d → %d frames", len(frames), len(kept))
    return kept


def _sample_evenly(frames: list[np.ndarray], n: int) -> list[np.ndarray]:
    if len(frames) <= n:
        return frames
    idx = [int(i * (len(frames) - 1) / (n - 1)) for i in range(n)]
    return [frames[i] for i in idx]


def _select_frames(frames: list[np.ndarray], n: int = 3) -> list[np.ndarray]:
    """Resize → enhance → quality filter → dedup → sample."""
    processed = [_resize(_enhance(f)) for f in frames]
    processed = _quality_filter(processed)
    processed = _deduplicate(processed)
    return _sample_evenly(processed, n)


# ─────────────────────────────────────────────────────────────────────────────
# JSON helpers
# ─────────────────────────────────────────────────────────────────────────────

def _parse_json(raw: str) -> dict[str, Any]:
    text = raw.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    m = re.search(r"\{.*\}", text, re.DOTALL)
    if m:
        text = m.group(0)
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"JSON parse error: {exc}\nRaw snippet:\n{text[:600]}"
        ) from exc


def _safe_int(v: Any) -> int | None:
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def _safe_float(v: Any) -> float | None:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _safe_bool(v: Any) -> bool | None:
    if isinstance(v, bool):
        return v
    if isinstance(v, str):
        return v.lower() in ("true", "yes", "1")
    return None


# ─────────────────────────────────────────────────────────────────────────────
# Stage prompts  (short, focused, Gemma-friendly)
# ─────────────────────────────────────────────────────────────────────────────

_SKIN_PROMPT = """You are a neonatal clinical vision assistant.
Examine this single baby image for skin findings only.

Return ONLY a valid JSON object with exactly these keys — no extra text:
{
  "jaundice_present": true/false/null,
  "kramer_zone": 1/2/3/4/5/null,
  "zone_body_region": "face_and_neck"|"chest_and_upper_abdomen"|"lower_abdomen_and_thighs"|"arms_and_lower_legs"|"palms_and_soles"|null,
  "jaundice_depth": "lemon_yellow"|"deep_orange"|null,
  "scleral_icterus_visible": true/false/null,
  "kramer_alert": true/false,
  "critical_hyperbilirubinemia": true/false,
  "central_cyanosis_present": true/false/null,
  "acrocyanosis_present": true/false/null,
  "pallor_detected": true/false/null,
  "mottling_detected": true/false/null,
  "skin_tone_category": "fair"|"medium"|"dark"|null,
  "skin_lesions_present": true/false/null,
  "petechiae_detected": true/false/null,
  "purpura_detected": true/false/null,
  "ecchymosis_detected": true/false/null,
  "blueberry_muffin_pattern": true/false/null,
  "lesion_alert": true/false
}

Rules:
- Kramer zone 1=face/neck, 2=chest/upper abdomen, 3=lower abdomen+thighs,
  4=arms+lower legs, 5=palms+soles.
- Set kramer_alert=true if zone>=3.
- Set critical_hyperbilirubinemia=true if zone>=4.
- Use null for anything not clearly visible.
Return ONLY the JSON object."""


_RESPIRATORY_PROMPT = """You are a neonatal clinical vision assistant.
Examine this baby image for breathing and chest findings only.

Silverman-Andersen scoring (0/1/2 each):
  upper_chest_movement: 0=normal, 1=lagging, 2=see-saw
  lower_chest_retractions: 0=none, 1=mild, 2=marked
  xiphoid_retraction: 0=none, 1=mild, 2=marked
  nasal_flaring: 0=none, 1=minimal, 2=marked

Return ONLY a valid JSON object with exactly these keys:
{
  "respiratory_rate_bpm": number or null,
  "breathing_regularity": "regular"|"irregular"|"periodic"|null,
  "upper_chest_movement": 0/1/2/null,
  "lower_chest_retractions": 0/1/2/null,
  "xiphoid_retraction": 0/1/2/null,
  "nasal_flaring": 0/1/2/null,
  "tachypnea_alert": true/false,
  "bradypnea_alert": true/false,
  "apnea_event_detected": true/false/null,
  "respiratory_alert": true/false,
  "lighting_condition": "bright"|"dim"|"variable"|null,
  "infant_position": "supine"|"prone"|"lateral"|"upright"|null
}

Tachypnea = RR > 60 bpm. Bradypnea = RR < 30 bpm.
Only report what you can actually see. Use null otherwise.
Return ONLY the JSON object."""


_MOVEMENT_PROMPT = """You are a neonatal clinical vision assistant.
Examine this baby image for movement, posture, and neurology only.

NBAS states: 1=deep_sleep, 2=active_sleep, 3=drowsy,
             4=quiet_alert, 5=active_alert, 6=crying
Prechtl: "normal_complexity"|"poor_repertoire"|"cramped_synchronized"|"absent"
NIPS items (0/1):
  facial_expression: 0=relaxed, 1=grimace
  arms: 0=relaxed, 1=flexed/rigid
  legs: 0=relaxed, 1=flexed/rigid
  state_of_arousal: 0=sleeping/calm, 1=fussy/agitated

Return ONLY a valid JSON object with exactly these keys:
{
  "nbas_state_code": 1/2/3/4/5/6/null,
  "nbas_state_label": "deep_sleep"|"active_sleep"|"drowsy"|"quiet_alert"|"active_alert"|"crying"|null,
  "eyes_open": true/false/null,
  "spontaneous_movement_present": true/false/null,
  "facial_expression": 0/1/null,
  "arms": 0/1/null,
  "legs": 0/1/null,
  "state_of_arousal": 0/1/null,
  "muscle_tone_assessment": "normal"|"hypotonic"|"hypertonic"|null,
  "frog_leg_posture_detected": true/false/null,
  "prechtl_classification": "normal_complexity"|"poor_repertoire"|"cramped_synchronized"|"absent"|null,
  "rhythmic_tremor_detected": true/false/null,
  "suppressible_by_holding": true/false/null,
  "ocular_deviation_detected": true/false/null,
  "seizure_risk": "LOW"|"MODERATE"|"HIGH"|null,
  "jitteriness_suspected": true/false/null,
  "neurological_alert": true/false,
  "abdominal_contour": "flat"|"scaphoid"|"distended"|null,
  "facial_symmetry": true/false/null,
  "dysmorphic_features_suspected": true/false/null
}

Return ONLY the JSON object."""


_JB_PROMPT = """You are a neonatal clinical vision assistant.
Examine this baby image for jaundice and breathing signs only.

Return ONLY a valid JSON object with exactly these keys:
{
  "jaundice_detected": true/false/null,
  "yellowing_zone": "face"|"chest"|"abdomen"|"full_body"|"none"|"unclear",
  "jaundice_confidence": 0.0,
  "breathing_pattern": "normal"|"shallow"|"irregular"|"not_visible",
  "estimated_breathing_rate": null,
  "breathing_risk": "low"|"moderate"|"high"|"unknown",
  "breathing_confidence": 0.0,
  "limitations": []
}

Use null only when truly not visible.
Return ONLY the JSON object."""


# ─────────────────────────────────────────────────────────────────────────────
# Stage runner
# ─────────────────────────────────────────────────────────────────────────────

def _run_stage(name: str, prompt: str, imgs: list[bytes]) -> dict[str, Any]:
    t0 = time.perf_counter()
    try:
        raw = _chat(prompt, images=imgs)
        logger.debug("[%s] raw: %s", name, raw[:300])
        data = _parse_json(raw)
        non_null = sum(1 for v in data.values() if v is not None)
        logger.info("[%s] %.2fs — %d/%d keys non-null",
                    name, time.perf_counter() - t0, non_null, len(data))
        return data
    except Exception as exc:
        logger.error("[%s] failed (non-fatal): %s", name, exc)
        return {}


# ─────────────────────────────────────────────────────────────────────────────
# Result merger
# ─────────────────────────────────────────────────────────────────────────────

def _merge(
    skin: dict[str, Any],
    resp: dict[str, Any],
    move: dict[str, Any],
    ts: str,
) -> dict[str, Any]:
    """Assemble stage outputs into the BabyVideoAnalysis-compatible dict."""

    # Silverman-Andersen total
    sa_fields = ["upper_chest_movement", "lower_chest_retractions",
                 "xiphoid_retraction", "nasal_flaring"]
    sa_vals = [_safe_int(resp.get(k)) for k in sa_fields]
    sa_total = (
        sum(v for v in sa_vals if v is not None)
        if any(v is not None for v in sa_vals) else None
    )
    sa_label = (
        None if sa_total is None else
        "no_distress" if sa_total == 0 else
        "mild" if sa_total <= 3 else
        "moderate" if sa_total <= 6 else "severe"
    )

    # NIPS total
    nips_fields = ["facial_expression", "arms", "legs", "state_of_arousal"]
    nips_vals = [_safe_int(move.get(k)) for k in nips_fields]
    nips_total = (
        sum(v for v in nips_vals if v is not None)
        if any(v is not None for v in nips_vals) else None
    )
    pain_level = (
        None if nips_total is None else
        "no_pain" if nips_total <= 2 else
        "mild" if nips_total <= 4 else "significant"
    )

    # IMNCI flags
    sa_gte_7 = bool(sa_total is not None and sa_total >= 7)
    tachypnea = _safe_bool(resp.get("tachypnea_alert")) or False
    cyanosis = _safe_bool(skin.get("central_cyanosis_present")) or False
    seizure = move.get("seizure_risk") == "HIGH"
    any_danger = any([sa_gte_7, tachypnea, cyanosis, seizure])

    # Active alerts list
    active_alerts: list[str] = []
    if sa_gte_7:
        active_alerts.append("severe_respiratory_distress")
    if tachypnea:
        active_alerts.append("tachypnea")
    if cyanosis:
        active_alerts.append("central_cyanosis")
    if seizure:
        active_alerts.append("seizure_risk_high")
    if _safe_bool(skin.get("kramer_alert")):
        active_alerts.append("jaundice_zone_3_or_above")
    if _safe_bool(skin.get("critical_hyperbilirubinemia")):
        active_alerts.append("critical_hyperbilirubinemia")
    if _safe_bool(move.get("neurological_alert")):
        active_alerts.append("neurological_alert")

    escalate = any_danger or bool(active_alerts)
    priority = "CRITICAL" if any_danger else ("HIGH" if active_alerts else "ROUTINE")

    return {
        "session_metadata": {
            "analysis_timestamp": ts,
            "video_duration_seconds": None,
            "lighting_condition": resp.get("lighting_condition"),
            "infant_position": resp.get("infant_position"),
            "skin_tone_category": skin.get("skin_tone_category"),
            "assessment_limitations": [],
        },
        "behavioral_state": {
            "nbas_state_code": _safe_int(move.get("nbas_state_code")),
            "nbas_state_label": move.get("nbas_state_label"),
            "eyes_open": _safe_bool(move.get("eyes_open")),
            "spontaneous_movement_present": _safe_bool(move.get("spontaneous_movement_present")),
            "state_stability": None,
        },
        "dermatology": {
            "jaundice": {
                "present": _safe_bool(skin.get("jaundice_present")),
                "kramer_zone": _safe_int(skin.get("kramer_zone")),
                "zone_body_region": skin.get("zone_body_region"),
                "depth": skin.get("jaundice_depth"),
                "scleral_icterus_visible": _safe_bool(skin.get("scleral_icterus_visible")),
                "estimated_tsb_mg_dl_range": None,
                "confidence": None,
                "kramer_alert": _safe_bool(skin.get("kramer_alert")) or False,
                "critical_hyperbilirubinemia": _safe_bool(skin.get("critical_hyperbilirubinemia")) or False,
            },
            "skin_lesions": {
                "present": _safe_bool(skin.get("skin_lesions_present")),
                "petechiae_detected": _safe_bool(skin.get("petechiae_detected")),
                "purpura_detected": _safe_bool(skin.get("purpura_detected")),
                "ecchymosis_detected": _safe_bool(skin.get("ecchymosis_detected")),
                "blueberry_muffin_pattern": _safe_bool(skin.get("blueberry_muffin_pattern")),
                "lesion_distribution": None,
                "body_regions_affected": None,
                "dominant_color": None,
                "dominant_size_category": None,
                "lesion_alert": _safe_bool(skin.get("lesion_alert")) or False,
                "suspected_etiology_flag": None,
            },
            "central_cyanosis": {
                "present": _safe_bool(skin.get("central_cyanosis_present")),
                "regions_affected": None,
                "note": None,
            },
            "acrocyanosis": {
                "present": _safe_bool(skin.get("acrocyanosis_present")),
                "note": None,
            },
            "pallor_detected": _safe_bool(skin.get("pallor_detected")),
            "mottling_detected": _safe_bool(skin.get("mottling_detected")),
        },
        "respiratory": {
            "respiratory_rate_bpm": _safe_float(resp.get("respiratory_rate_bpm")),
            "measurement_window_seconds": None,
            "breathing_regularity": resp.get("breathing_regularity"),
            "silverman_andersen": {
                "upper_chest_movement": _safe_int(resp.get("upper_chest_movement")),
                "lower_chest_retractions": _safe_int(resp.get("lower_chest_retractions")),
                "xiphoid_retraction": _safe_int(resp.get("xiphoid_retraction")),
                "nasal_flaring": _safe_int(resp.get("nasal_flaring")),
                "expiratory_grunt": None,       # requires audio
                "total_score": sa_total,
                "severity_label": sa_label,
            },
            "tachypnea_alert": _safe_bool(resp.get("tachypnea_alert")) or False,
            "bradypnea_alert": _safe_bool(resp.get("bradypnea_alert")) or False,
            "apnea_event_detected": _safe_bool(resp.get("apnea_event_detected")),
            "apnea_duration_seconds": None,
            "respiratory_alert": _safe_bool(resp.get("respiratory_alert")) or False,
        },
        "pain_assessment_nips": {
            "facial_expression": _safe_int(move.get("facial_expression")),
            "cry": None,                        # requires audio
            "breathing_pattern_change": None,
            "arms": _safe_int(move.get("arms")),
            "legs": _safe_int(move.get("legs")),
            "state_of_arousal": _safe_int(move.get("state_of_arousal")),
            "total_nips_score": nips_total,
            "pain_level": pain_level,
            "clinical_pain_indicated": bool(nips_total and nips_total >= 3),
        },
        "neurology_and_kinematics": {
            "muscle_tone": {
                "assessment": move.get("muscle_tone_assessment"),
                "frog_leg_posture_detected": _safe_bool(move.get("frog_leg_posture_detected")),
                "w_arm_posture_detected": None,
                "note": None,
            },
            "head_and_neck": None,
            "limb_symmetry": None,
            "general_movement_quality": {
                "prechtl_classification": move.get("prechtl_classification"),
                "fidgety_movements_present": None,
                "movement_description": None,
            },
            "seizure_vs_jitteriness": {
                "rhythmic_tremor_detected": _safe_bool(move.get("rhythmic_tremor_detected")),
                "tremor_frequency": None,
                "suppressible_by_holding": _safe_bool(move.get("suppressible_by_holding")),
                "ocular_deviation_detected": _safe_bool(move.get("ocular_deviation_detected")),
                "lip_smacking_detected": None,
                "concurrent_apnea_with_tremor": None,
                "seizure_risk": move.get("seizure_risk"),
                "jitteriness_suspected": _safe_bool(move.get("jitteriness_suspected")),
            },
            "neurological_alert": _safe_bool(move.get("neurological_alert")) or False,
        },
        "gastrointestinal": {
            "abdominal_contour": move.get("abdominal_contour"),
            "abdominal_distension_alert": None,
            "visible_venous_engorgement": None,
            "abdominal_wall_shiny": None,
        },
        "craniofacial_morphology": {
            "facial_symmetry": _safe_bool(move.get("facial_symmetry")),
            "dysmorphic_features_suspected": _safe_bool(move.get("dysmorphic_features_suspected")),
            "ear_position": None,
            "eye_spacing": None,
            "palpebral_fissure_slant": None,
            "nasal_bridge": None,
            "dysmorphology_note": None,
        },
        "imnci_danger_signs": {
            "extreme_lethargy_or_unconsciousness": False,
            "severe_chest_indrawing_sa_score_gte_7": sa_gte_7,
            "sustained_tachypnea_rr_gt_60": tachypnea,
            "central_cyanosis_present": cyanosis,
            "convulsions_or_seizure_activity": seizure,
            "any_danger_sign_active": any_danger,
        },
        "escalation": {
            "escalate_immediately": escalate,
            "priority_level": priority,
            "active_alerts": active_alerts or None,
            "clinical_reasoning": (
                "Automated staged Gemma-4 analysis via local Ollama. "
                "Clinical review required before acting on these findings."
            ),
            "recommended_actions": (
                ["Immediate clinical review"] if escalate else ["Routine monitoring"]
            ),
        },
    }


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

async def analyze_video_with_ai(
    frames: list[np.ndarray],
    has_audio: bool = False,
    audio_context: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    Staged neonatal video analysis optimised for local Gemma-4 via Ollama.

    Runs three focused single-frame inferences (skin, respiratory, movement)
    then merges + validates against BabyVideoAnalysis.
    """
    if not frames:
        raise HTTPException(status_code=422, detail="No frames provided.")

    try:
        ts = datetime.now(timezone.utc).isoformat()
        t0 = time.perf_counter()

        # Select up to 4 high-quality, distinct frames
        best = _select_frames(frames, n=min(4, len(frames)))
        logger.info("Staged pipeline: %d selected from %d total frames",
                    len(best), len(frames))

        # Use a different frame per stage when possible (avoids identical input)
        f0 = best[0]
        f1 = best[min(1, len(best) - 1)]
        f2 = best[min(2, len(best) - 1)]

        skin_data = _run_stage("skin",        _SKIN_PROMPT,        [_to_jpeg(f0)])
        resp_data = _run_stage("respiratory", _RESPIRATORY_PROMPT, [_to_jpeg(f1)])
        move_data = _run_stage("movement",    _MOVEMENT_PROMPT,    [_to_jpeg(f2)])

        merged = _merge(skin_data, resp_data, move_data, ts)
        validated = BabyVideoAnalysis.model_validate(merged)

        logger.info("analyze_video_with_ai done in %.2fs (model=%s)",
                    time.perf_counter() - t0, _ACTIVE_MODEL)
        return validated.model_dump(mode="json")

    except HTTPException:
        raise
    except ValueError as ve:
        raise HTTPException(status_code=422, detail=str(ve)) from ve
    except RuntimeError as re_:
        raise HTTPException(status_code=503, detail=f"Ollama error: {re_}") from re_
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {exc}") from exc


async def analyze_jaundice_breathing_with_ai(
    frames: list[np.ndarray],
) -> dict[str, Any]:
    """Lightweight jaundice + breathing analysis (single frame, one inference)."""
    if not frames:
        raise HTTPException(status_code=422, detail="No frames provided.")

    try:
        t0 = time.perf_counter()
        best = _select_frames(frames, n=2)

        raw = _chat(_JB_PROMPT, images=[_to_jpeg(best[0])])
        result = _parse_json(raw)

        result.setdefault("timestamp_utc", datetime.now(timezone.utc).isoformat())
        result.setdefault("analysis_status", "success")

        validated = JaundiceBreathingAnalysis.model_validate(result)

        logger.info("analyze_jaundice_breathing_with_ai done in %.2fs",
                    time.perf_counter() - t0)
        return validated.model_dump(mode="json")

    except HTTPException:
        raise
    except ValueError as ve:
        raise HTTPException(status_code=422, detail=str(ve)) from ve
    except RuntimeError as re_:
        raise HTTPException(status_code=503, detail=f"Ollama error: {re_}") from re_
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {exc}") from exc