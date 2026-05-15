import 'package:flutter/material.dart';
import 'base_analyzer_page.dart';

class JaundiceAnalyzerPage extends StatelessWidget {
  const JaundiceAnalyzerPage({super.key});

  static const String promptTemplate = '''
  Analyze the image of a newborn for signs of neonatal Jaundice (Icterus).
  
  CRITICAL CLINICAL MARKERS:
  1. Skin Tone: Look for ANY yellowish, golden, or lemon-yellow tint. Compare the baby's skin to the skin of any adult hand in the frame (if visible) or typical neutral tones. 
  2. Eyes (Sclera): Check if the whites of the eyes show any yellowing. This is a key indicator of elevated bilirubin.
  3. Progression: Jaundice usually starts at the face and moves down the body. 
     - "Severe Jaundice" if yellowing is deep, visible in eyes, and covers all visible skin.
     - "Moderate Jaundice" if yellowing is clear on face and chest.
     - "Mild Jaundice" if only a faint yellowing is visible on the face.
     - "Normal" ONLY if the skin has no yellow undertones.

  Provide the analysis in this JSON format ONLY. Do NOT add recommendations.
  {
    "diagnosis": "Normal / Mild Jaundice / Moderate Jaundice / Severe Jaundice",
    "confidence": 0.0 to 1.0,
    "thinking": "Detailed clinical reasoning focusing on skin tone comparison and sclera color."
  }
  Only return the JSON. Do not include a recommendations field.
''';

  static const Map<String, List<String>> recommendationMap = {
    'normal': [
      "Continue standard newborn care and feeding regimen.",
      "Ensure adequate feeding (breastfeeding or formula) to support bilirubin clearance.",
      "Monitor for any yellowing of the skin or eyes over the next 48 hours."
    ],
    'mild': [
      "Increase feeding frequency (8-12 times per day) to help the baby pass bilirubin through stool.",
      "Ensure the baby is well-hydrated.",
      "Consult a pediatrician within 24 hours for a physical examination and potential bilirubin blood test."
    ],
    'moderate': [
      "IMMEDIATE pediatric consultation required.",
      "Bilirubin blood test (TSB) or transcutaneous bilirubinometry (TcB) is likely necessary.",
      "Prepare for potential phototherapy as advised by a clinician."
    ],
    'severe': [
      "CRITICAL: Immediate emergency medical attention required.",
      "Hospitalization for intensive phototherapy or exchange transfusion may be necessary.",
      "Risk of kernicterus (brain damage) if left untreated. Do not delay."
    ]
  };

  @override
  Widget build(BuildContext context) {
    return const BaseAnalyzerPage(
      title: 'Jaundice Analyzer',
      subtitle: 'Visual bilirubin assessment',
      themeColor: Colors.cyan,
      icon: Icons.search_rounded,
      mode: 'visual_only',
      promptTemplate: promptTemplate,
      defectInfo: 'Neonatal jaundice is a common condition where a baby\'s skin and eyes look yellow because of high bilirubin levels. While often harmless, it occurs when a baby\'s liver isn\'t developed enough to remove bilirubin from the bloodstream.',
      defectHarm: 'If left untreated, extremely high bilirubin levels can lead to kernicterus—a type of permanent brain damage. Severe jaundice requires phototherapy or exchange transfusion to prevent neurodevelopmental complications or hearing loss.',
      recommendationMap: recommendationMap,
    );
  }
}
