import 'package:flutter/material.dart';
import 'base_analyzer_page.dart';

class AsphyxiaAnalyzerPage extends StatelessWidget {
  const AsphyxiaAnalyzerPage({super.key});

  static const String promptTemplate = '''
  Analyze the provided video (visual frames and audio) of a newborn for signs of Birth Asphyxia.
  
  CLINICAL MARKERS TO ASSESS:
  1. Visual Cues:
     - Skin Color: Look for Cyanosis (blue or pale discoloration of skin, lips, or extremities).
     - Muscle Tone: Look for lack of movement, limpness, or hypotonia.
     - Respiratory Effort: Look for chest retractions, gasping, or absence of breathing.
  2. Audio Cues:
     - Cry Pattern: Listen for a weak, absent, or abnormally high-pitched cry.
  
  INTEGRATION:
  Combine both visual and acoustic observations to determine the risk of Birth Asphyxia.
  
  Provide the analysis in this JSON format ONLY:
  {
    "diagnosis": "None / Mild Risk / Moderate Risk / Severe Risk",
    "confidence": 0.0 to 1.0,
    "thinking": "Step-by-step clinical reasoning integrating visual color/tone with audio cry patterns.",
    "visual_observations": "Summary of visual findings",
    "audio_observations": "Summary of acoustic findings"
  }
  Only return the JSON. Do not include a recommendations field as they are standardized.
''';

  static const Map<String, List<String>> recommendationMap = {
    'none': [
      "Ensure standard newborn warmth and monitoring.",
      "Monitor for any delayed onset of respiratory effort.",
      "Support immediate skin-to-skin contact if stable."
    ],
    'mild': [
      "Provide tactile stimulation (rubbing the back or soles of feet).",
      "Clear the airway with a bulb syringe if secretions are present.",
      "Monitor heart rate and respiratory effort closely.",
      "Consult a pediatrician for a brief evaluation."
    ],
    'moderate': [
      "Initiate positive pressure ventilation (PPV) if heart rate is < 100 bpm.",
      "Immediate neonatologist or pediatrician presence required.",
      "Transfer to a Neonatal Intensive Care Unit (NICU) for observation.",
      "Monitor blood glucose and electrolytes."
    ],
    'severe': [
      "CRITICAL EMERGENCY: Immediate full resuscitation required (NRP protocol).",
      "Endotracheal intubation and chest compressions if indicated.",
      "Consider therapeutic hypothermia (cooling therapy) within 6 hours.",
      "Continuous monitoring of vitals and neurological status in Level III NICU."
    ]
  };

  @override
  Widget build(BuildContext context) {
    return const BaseAnalyzerPage(
      title: 'Asphyxia Analyzer',
      subtitle: 'Oxygen deprivation detection',
      themeColor: Colors.pink,
      icon: Icons.favorite_rounded,
      mode: 'video_audio',
      promptTemplate: promptTemplate,
      defectInfo: 'Birth Asphyxia occurs when a baby does not receive enough oxygen before, during, or immediately after birth. It is a leading cause of neonatal mortality and long-term neurological disabilities.',
      defectHarm: 'Prolonged oxygen deprivation can lead to Hypoxic-Ischemic Encephalopathy (HIE), causing permanent brain damage, cerebral palsy, or multi-organ failure. Immediate detection and resuscitation are critical to survival.',
      recommendationMap: recommendationMap,
    );
  }
}
