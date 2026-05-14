import uuid

from datetime import datetime
from typing import Optional, List, Dict, Any

from sqlalchemy import String, Float, Integer, Boolean, DateTime, ForeignKey, Text, JSON, ARRAY, func
from sqlalchemy.dialects.postgresql import TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from db.db import Base



class BabyAdvancedAssessment(Base):
    __tablename__ = "BabyAdvancedAssessment"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4
    )

    baby_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True
    )

    baby_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    baby_sex: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    baby_birth_date: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
        index=True
    )

    # =========================
    # SESSION METADATA
    # =========================
    analysis_timestamp: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    video_duration_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    lighting_condition: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    infant_position: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    skin_tone_category: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    assessment_limitations: Mapped[Optional[List[str]]] = mapped_column(JSON, nullable=True)

    # =========================
    # BEHAVIORAL STATE
    # =========================
    nbas_state_code: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    nbas_state_label: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    eyes_open: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    spontaneous_movement_present: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    state_stability: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    # =========================
    # JAUNDICE
    # =========================
    jaundice_present: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    kramer_zone: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    zone_body_region: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    jaundice_depth: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    scleral_icterus_visible: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    estimated_tsb_mg_dl_range: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    jaundice_confidence: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    kramer_alert: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    critical_hyperbilirubinemia: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # =========================
    # SKIN LESIONS
    # =========================
    skin_lesions_present: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    petechiae_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    purpura_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    ecchymosis_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    blueberry_muffin_pattern: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    lesion_distribution: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    body_regions_affected: Mapped[Optional[List[str]]] = mapped_column(JSON, nullable=True)

    dominant_color: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    dominant_size_category: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    lesion_alert: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    suspected_etiology_flag: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # =========================
    # CYANOSIS
    # =========================
    central_cyanosis_present: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    central_cyanosis_regions_affected: Mapped[Optional[List[str]]] = mapped_column(JSON, nullable=True)

    central_cyanosis_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    acrocyanosis_present: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    acrocyanosis_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    pallor_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    mottling_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # =========================
    # RESPIRATORY
    # =========================
    respiratory_rate_bpm: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    measurement_window_seconds: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    breathing_regularity: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    upper_chest_movement: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    lower_chest_retractions: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    xiphoid_retraction: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    nasal_flaring: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    expiratory_grunt: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    silverman_total_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    respiratory_severity_label: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    tachypnea_alert: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    bradypnea_alert: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    apnea_event_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    apnea_duration_seconds: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    respiratory_alert: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # =========================
    # NIPS PAIN
    # =========================
    facial_expression_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    cry_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    breathing_pattern_change_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    arms_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    legs_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    state_of_arousal_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    total_nips_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    pain_level: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    clinical_pain_indicated: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # =========================
    # MUSCLE TONE
    # =========================
    muscle_tone_assessment: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    frog_leg_posture_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    w_arm_posture_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    muscle_tone_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    head_and_neck: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)

    limb_symmetry: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)

    # =========================
    # GENERAL MOVEMENTS
    # =========================
    prechtl_classification: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    fidgety_movements_present: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    movement_description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # =========================
    # SEIZURE / JITTERINESS
    # =========================
    rhythmic_tremor_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    tremor_frequency: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    suppressible_by_holding: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    ocular_deviation_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    lip_smacking_detected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    concurrent_apnea_with_tremor: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    seizure_risk: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    jitteriness_suspected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    neurological_alert: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # =========================
    # GASTROINTESTINAL
    # =========================
    abdominal_contour: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    abdominal_distension_alert: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    visible_venous_engorgement: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    abdominal_wall_shiny: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # =========================
    # CRANIOFACIAL
    # =========================
    facial_symmetry: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    dysmorphic_features_suspected: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    ear_position: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    eye_spacing: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    palpebral_fissure_slant: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    nasal_bridge: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    dysmorphology_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # =========================
    # IMNCI DANGER SIGNS
    # =========================
    extreme_lethargy_or_unconsciousness: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    severe_chest_indrawing_sa_score_gte_7: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    sustained_tachypnea_rr_gt_60: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    central_cyanosis_danger_present: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    convulsions_or_seizure_activity: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    any_danger_sign_active: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    # =========================
    # ESCALATION
    # =========================
    escalate_immediately: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)

    priority_level: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    active_alerts: Mapped[Optional[List[str]]] = mapped_column(JSON, nullable=True)

    clinical_reasoning: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    recommended_actions: Mapped[Optional[List[str]]] = mapped_column(JSON, nullable=True)