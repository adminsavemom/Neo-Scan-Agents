import 'package:flutter/material.dart';
import 'base_analyzer_page.dart';

class RdsAnalyzerPage extends StatelessWidget {
  const RdsAnalyzerPage({super.key});

  static const String promptTemplate = '''
  Analyze the provided video (visual frames and audio) of a newborn for signs of Respiratory Distress Syndrome (RDS).
  
  CLINICAL MARKERS TO ASSESS:
  1. Visual Cues:
     - Nasal Flaring: Look for widening of nostrils during inhalation.
     - Retractions: Look for intercostal (between ribs), subcostal (below ribs), or suprasternal (above collarbone) sinking.
     - Chest Expansion: Look for rapid breathing (tachypnea > 60 bpm) or paradoxical "see-saw" breathing.
  2. Audio Cues:
     - Grunting: Listen for expiratory grunting (a short, deep, throaty sound on exhaling).
     - Breath Sounds: Listen for any abnormal or labored breathing noises.
  
  INTEGRATION:
  Combine both visual breathing mechanics and acoustic sounds to determine the RDS risk level.
  
  Provide the analysis in this JSON format ONLY:
  {
    "diagnosis": "None / Mild RDS / Moderate RDS / Severe RDS",
    "confidence": 0.0 to 1.0,
    "thinking": "Step-by-step clinical reasoning integrating visual retractions with audio grunting patterns.",
    "visual_observations": "Summary of breathing mechanics",
    "audio_observations": "Summary of respiratory sounds"
  }
  Only return the JSON. Do not include a recommendations field as they are standardized.
''';

  static const Map<String, List<String>> recommendationMap = {
    'none': [
      "Continue regular monitoring of respiratory rate (normal is 40-60 bpm).",
      "Ensure the baby remains warm and maintains normal feeding.",
      "Monitor for any development of nasal flaring or retractions."
    ],
    'mild': [
      "Monitor respiratory rate and effort every 1-2 hours.",
      "Maintain clear nasal passages to reduce the work of breathing.",
      "Ensure the baby is in a supportive position (slightly elevated head).",
      "Consult a pediatrician for evaluation within 12-24 hours."
    ],
    'moderate': [
      "Immediate medical consultation is required.",
      "Prepare for supplemental oxygen or CPAP (Continuous Positive Airway Pressure) support.",
      "Monitor oxygen saturation continuously with pulse oximetry.",
      "Keep the baby NPO (nothing by mouth) if respiratory rate is very high."
    ],
    'severe': [
      "EMERGENCY: Immediate transfer to a Level III NICU.",
      "Requires advanced respiratory support (intubation or surfactant therapy).",
      "Provide high-flow oxygen or mechanical ventilation as indicated.",
      "Immediate chest X-ray and blood gas analysis are necessary."
    ]
  };

  @override
  Widget build(BuildContext context) {
    return const BaseAnalyzerPage(
      title: 'Respiratory Analyzer',
      subtitle: 'Breathing patterns & RDS',
      themeColor: Colors.teal,
      icon: Icons.air_rounded,
      mode: 'video_audio',
      promptTemplate: promptTemplate,
      defectInfo: 'Respiratory Distress Syndrome (RDS) is a common breathing disorder in newborns, primarily caused by a lack of surfactant in the lungs. It makes it difficult for the baby to breathe and keep the lungs open.',
      defectHarm: 'Untreated RDS can lead to severe hypoxia, respiratory failure, and long-term lung conditions like Bronchopulmonary Dysplasia (BPD). It can also cause air leaks (pneumothorax) or brain hemorrhage due to stress.',
      recommendationMap: recommendationMap,
    );
  }
}
