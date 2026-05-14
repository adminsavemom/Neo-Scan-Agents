from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime


# ── Session / metadata ────────────────────────────────────────────────────────

class SessionMetadata(BaseModel):
    analysis_timestamp: Optional[datetime] = None
    video_duration_seconds: Optional[float] = None
    lighting_condition: Optional[str] = None
    infant_position: Optional[str] = None
    skin_tone_category: Optional[str] = None
    assessment_limitations: Optional[List[str]] = None


# ── Behavioral state (NBAS) ──────────────────────────────────────────────────

class BehavioralState(BaseModel):
    nbas_state_code: Optional[int] = None
    nbas_state_label: Optional[str] = None
    eyes_open: Optional[bool] = None
    spontaneous_movement_present: Optional[bool] = None
    state_stability: Optional[str] = None


# ── Dermatology: Jaundice, Lesions, Cyanosis ──────────────────────────────────

class Jaundice(BaseModel):
    present: Optional[bool] = None
    kramer_zone: Optional[int] = None
    zone_body_region: Optional[str] = None
    depth: Optional[str] = None
    scleral_icterus_visible: Optional[bool] = None
    estimated_tsb_mg_dl_range: Optional[str] = None
    confidence: Optional[str] = None
    kramer_alert: Optional[bool] = None
    critical_hyperbilirubinemia: Optional[bool] = None


class SkinLesions(BaseModel):
    present: Optional[bool] = None
    petechiae_detected: Optional[bool] = None
    purpura_detected: Optional[bool] = None
    ecchymosis_detected: Optional[bool] = None
    blueberry_muffin_pattern: Optional[bool] = None
    lesion_distribution: Optional[str] = None
    body_regions_affected: Optional[List[str]] = None
    dominant_color: Optional[str] = None
    dominant_size_category: Optional[str] = None
    lesion_alert: Optional[bool] = None
    suspected_etiology_flag: Optional[str] = None


class CentralCyanosis(BaseModel):
    present: Optional[bool] = None
    regions_affected: Optional[List[Any]] = None
    note: Optional[str] = None


class Acrocyanosis(BaseModel):
    present: Optional[bool] = None
    note: Optional[str] = None


class Dermatology(BaseModel):
    jaundice: Optional[Jaundice] = None
    skin_lesions: Optional[SkinLesions] = None
    central_cyanosis: Optional[CentralCyanosis] = None
    acrocyanosis: Optional[Acrocyanosis] = None
    pallor_detected: Optional[bool] = None
    mottling_detected: Optional[bool] = None


# ── Respiratory (Silverman-Andersen) ──────────────────────────────────────────

class SilvermanAndersen(BaseModel):
    upper_chest_movement: Optional[int] = None
    lower_chest_retractions: Optional[int] = None
    xiphoid_retraction: Optional[int] = None
    nasal_flaring: Optional[int] = None
    expiratory_grunt: Optional[int] = None
    total_score: Optional[int] = None
    severity_label: Optional[str] = None


class Respiratory(BaseModel):
    respiratory_rate_bpm: Optional[float] = None
    measurement_window_seconds: Optional[float] = None
    breathing_regularity: Optional[str] = None
    silverman_andersen: Optional[SilvermanAndersen] = None
    tachypnea_alert: Optional[bool] = None
    bradypnea_alert: Optional[bool] = None
    apnea_event_detected: Optional[bool] = None
    apnea_duration_seconds: Optional[float] = None
    respiratory_alert: Optional[bool] = None


# ── Pain Assessment (NIPS) ────────────────────────────────────────────────────

class PainAssessmentNips(BaseModel):
    facial_expression: Optional[int] = None
    cry: Optional[int] = None
    breathing_pattern_change: Optional[int] = None
    arms: Optional[int] = None
    legs: Optional[int] = None
    state_of_arousal: Optional[int] = None
    total_nips_score: Optional[int] = None
    pain_level: Optional[str] = None
    clinical_pain_indicated: Optional[bool] = None


# ── Neurology & Kinematics (Prechtl, Seizure differentiation) ─────────────────

class MuscleTone(BaseModel):
    assessment: Optional[str] = None
    frog_leg_posture_detected: Optional[bool] = None
    w_arm_posture_detected: Optional[bool] = None
    note: Optional[str] = None


class HeadAndNeck(BaseModel):
    head_tilt_degrees: Optional[int] = None
    tilt_direction: Optional[str] = None
    torticollis_suspected: Optional[bool] = None
    opisthotonus_suspected: Optional[bool] = None
    chin_rotation_direction: Optional[str] = None


class LimbSymmetry(BaseModel):
    overall: Optional[str] = None
    affected_side: Optional[str] = None
    erbs_palsy_waiter_tip_detected: Optional[bool] = None
    asymmetry_index_description: Optional[str] = None


class GeneralMovementQuality(BaseModel):
    prechtl_classification: Optional[str] = None
    fidgety_movements_present: Optional[bool] = None
    movement_description: Optional[str] = None


class SeizureVsJitteriness(BaseModel):
    rhythmic_tremor_detected: Optional[bool] = None
    tremor_frequency: Optional[str] = None
    suppressible_by_holding: Optional[bool] = None
    ocular_deviation_detected: Optional[bool] = None
    lip_smacking_detected: Optional[bool] = None
    concurrent_apnea_with_tremor: Optional[bool] = None
    seizure_risk: Optional[str] = None
    jitteriness_suspected: Optional[bool] = None


class NeurologyAndKinematics(BaseModel):
    muscle_tone: Optional[MuscleTone] = None
    head_and_neck: Optional[HeadAndNeck] = None
    limb_symmetry: Optional[LimbSymmetry] = None
    general_movement_quality: Optional[GeneralMovementQuality] = None
    seizure_vs_jitteriness: Optional[SeizureVsJitteriness] = None
    neurological_alert: Optional[bool] = None


# ── Gastrointestinal ──────────────────────────────────────────────────────────

class Gastrointestinal(BaseModel):
    abdominal_contour: Optional[str] = None
    abdominal_distension_alert: Optional[bool] = None
    visible_venous_engorgement: Optional[bool] = None
    abdominal_wall_shiny: Optional[bool] = None


# ── Craniofacial Morphology ───────────────────────────────────────────────────

class CraniofacialMorphology(BaseModel):
    facial_symmetry: Optional[bool] = None
    dysmorphic_features_suspected: Optional[bool] = None
    ear_position: Optional[str] = None
    eye_spacing: Optional[str] = None
    palpebral_fissure_slant: Optional[str] = None
    nasal_bridge: Optional[str] = None
    dysmorphology_note: Optional[str] = None


# ── IMNCI Danger Signs (WHO / IAP) ───────────────────────────────────────────

class ImnciDangerSigns(BaseModel):
    extreme_lethargy_or_unconsciousness: Optional[bool] = None
    severe_chest_indrawing_sa_score_gte_7: Optional[bool] = None
    sustained_tachypnea_rr_gt_60: Optional[bool] = None
    central_cyanosis_present: Optional[bool] = None
    convulsions_or_seizure_activity: Optional[bool] = None
    any_danger_sign_active: Optional[bool] = None


# ── Escalation ────────────────────────────────────────────────────────────────

class Escalation(BaseModel):
    escalate_immediately: Optional[bool] = None
    priority_level: Optional[str] = None
    active_alerts: Optional[List[str]] = None
    clinical_reasoning: Optional[str] = None
    recommended_actions: Optional[List[str]] = None


# ── Top-level response model ─────────────────────────────────────────────────

class BabyVideoAnalysis(BaseModel):
    """
    Full clinical neonatal video analysis response.

    Covers: NBAS consciousness state, Kramer jaundice zones, Silverman-Andersen
    respiratory score, NIPS pain scale, Prechtl general movement assessment,
    IMNCI danger signs, seizure vs jitteriness differentiation, craniofacial
    morphology, gastrointestinal assessment, and clinical escalation.
    """

    session_metadata: Optional[SessionMetadata] = None
    behavioral_state: Optional[BehavioralState] = None
    dermatology: Optional[Dermatology] = None
    respiratory: Optional[Respiratory] = None
    pain_assessment_nips: Optional[PainAssessmentNips] = None
    neurology_and_kinematics: Optional[NeurologyAndKinematics] = None
    gastrointestinal: Optional[Gastrointestinal] = None
    craniofacial_morphology: Optional[CraniofacialMorphology] = None
    imnci_danger_signs: Optional[ImnciDangerSigns] = None
    escalation: Optional[Escalation] = None


# ── Jaundice & Breathing Simplified Models ───────────────────────────────────

from enum import Enum

class YellowingZoneEnum(str, Enum):
    none = "none"
    face = "face"
    chest = "chest"
    abdomen = "abdomen"
    full_body = "full_body"
    unclear = "unclear"

class ChestMovementEnum(str, Enum):
    normal = "normal"
    shallow = "shallow"
    irregular = "irregular"
    not_visible = "not_visible"

class BreathingRiskEnum(str, Enum):
    low = "low"
    moderate = "moderate"
    high = "high"
    unknown = "unknown"

class JaundiceAnalysis(BaseModel):
    visible_yellowing: bool
    yellowing_zone: YellowingZoneEnum
    confidence: float

class BreathingAnalysis(BaseModel):
    breathing_visible: bool
    chest_movement: ChestMovementEnum
    breathing_risk: BreathingRiskEnum
    estimated_breathing_rate: Optional[float] = None
    confidence: float

class JaundiceBreathingAnalysis(BaseModel):
    analysis_status: str
    jaundice_analysis: JaundiceAnalysis
    breathing_analysis: BreathingAnalysis
    limitations: List[str]
    overall_confidence: float
    timestamp_utc: str

class JaundiceBreathingRequest(BaseModel):
    video_url: str
