
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
