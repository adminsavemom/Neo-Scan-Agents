import 'package:flutter/material.dart';
import 'base_analyzer_page.dart';

class CryAnalyzerPage extends StatelessWidget {
  const CryAnalyzerPage({super.key});

  static const String promptTemplate = '''
  You are an expert in neonatal acoustic analysis. Analyze the baby cry pattern from the provided audio track.
  
  ACOUSTIC MARKERS TO EVALUATE:
  1. Pitch (Fundamental Frequency): High pitch can indicate pain or neurological distress.
  2. Rhythm & Intensity: Sudden bursts vs. rhythmic patterns.
  3. Pauses (Inspiratory/Expiratory): Duration of pauses between cries.
  4. Harmonic Quality: Clear vs. hoarse or strident.
  
  CLINICAL CONTEXT MAPPING:
  - "Hunger Cry": Rhythmic, repetitive, often includes a "neh" sound (sucking reflex).
  - "Pain Cry": Sudden onset, high pitch, long initial cry followed by breath-holding.
  - "Discomfort Cry": Whiny, nasal, lower intensity, non-rhythmic.
  - "Tired Cry": Breathy, "yawny" sound, often builds up slowly.
  - "Normal / None": No distress patterns or no cry detected.

  Provide the analysis in this JSON format ONLY. Do NOT add recommendations.
  {
    "diagnosis": "Hunger Cry / Pain Cry / Discomfort Cry / Tired Cry / No Cry Detected",
    "confidence": 0.0 to 1.0,
    "thinking": "Step-by-step acoustic reasoning integrating pitch, rhythm, and temporal patterns."
  }
  Only return the JSON. Do not include a recommendations field.
  ''';

  static const Map<String, List<String>> recommendationMap = {
    'hunger': [
      "Check feeding schedule and offer breast/bottle.",
      "Look for rooting reflexes or hand-to-mouth movements.",
      "Burp the baby halfway through feeding if they seem restless."
    ],
    'pain': [
      "Check for tight clothing, diaper pins, or hair tourniquets on fingers/toes.",
      "Monitor for fever or other signs of physical illness.",
      "Try the '5 S's' (Swaddle, Side/Stomach, Shush, Swing, Suck) for soothing.",
      "Consult a pediatrician if the cry is persistent and inconsolable."
    ],
    'discomfort': [
      "Check diaper status and change if necessary.",
      "Assess room temperature and adjust clothing layers.",
      "Check for gas or bloating; try 'bicycle legs' or tummy time."
    ],
    'tired': [
      "Move to a quiet, dimly lit environment.",
      "Swaddle the baby and use white noise if helpful.",
      "Avoid overstimulation (bright lights, loud noises, many people)."
    ],
    'normal': [
      "Newborn is displaying healthy vocalizations.",
      "Monitor for any changes in cry patterns.",
      "Ensure standard care routines are followed."
    ],
  };

  @override
  Widget build(BuildContext context) {
    return BaseAnalyzerPage(
      title: 'Cry Analyzer',
      subtitle: 'Acoustic pattern assessment',
      icon: Icons.volume_up_rounded,
      themeColor: Colors.purple,
      promptTemplate: promptTemplate,
      recommendationMap: recommendationMap,
      mode: 'video_audio', // New mode: Select video, extract audio
      defectInfo: 'Analyzes the acoustic signature of a baby\'s cry to help identify underlying needs or distress levels.',
      defectHarm: 'Failure to identify specific cry types (like pain or hunger) can lead to prolonged distress or delayed medical attention for underlying issues.',
    );
  }
}
