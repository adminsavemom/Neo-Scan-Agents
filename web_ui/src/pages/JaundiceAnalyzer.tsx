import BaseAnalyzer from './BaseAnalyzer';
import { Search } from 'lucide-react';

const JaundiceAnalyzer = () => {
  const promptTemplate = `
  Analyze the image of a newborn for signs of neonatal Jaundice (Icterus).
  
  CRITICAL CLINICAL MARKERS:
  1. Skin Tone: Look for ANY yellowish, golden, or lemon-yellow tint. Compare the baby's skin to the skin of any adult hand in the frame (if visible) or typical neutral tones. 
  2. Eyes (Sclera): Check if the whites of the eyes show any yellowing. This is a key indicator of elevated bilirubin.
  3. Progression: Jaundice usually starts at the face and moves down the body. 
     - "Severe Jaundice" if yellowing is deep, visible in eyes, and covers all visible skin.
     - "Moderate Jaundice" if yellowing is clear on face and chest.
     - "Mild Jaundice" if only a faint yellowing is visible on the face.
     - "Normal" ONLY if the skin has no yellow undertones.

  Provide the analysis in this JSON format:
  {
    "diagnosis": "Normal / Mild Jaundice / Moderate Jaundice / Severe Jaundice",
    "confidence": 0.0 to 1.0,
    "thinking": "Detailed clinical reasoning focusing on skin tone comparison and sclera color.",
    "recommendations": []
  }
  Only return the JSON.
`;

  const recommendationMap = {
    normal: [
      "Continue standard newborn care and feeding regimen.",
      "Ensure adequate feeding (breastfeeding or formula) to support bilirubin clearance.",
      "Monitor for any yellowing of the skin or eyes over the next 48 hours."
    ],
    mild: [
      "Increase feeding frequency (8-12 times per day) to help the baby pass bilirubin through stool.",
      "Ensure the baby is well-hydrated.",
      "Consult a pediatrician within 24 hours for a physical examination and potential bilirubin blood test."
    ],
    moderate: [
      "IMMEDIATE pediatric consultation required.",
      "Bilirubin blood test (TSB) or transcutaneous bilirubinometry (TcB) is likely necessary.",
      "Prepare for potential phototherapy as advised by a clinician."
    ],
    severe: [
      "CRITICAL: Immediate emergency medical attention required.",
      "Hospitalization for intensive phototherapy or exchange transfusion may be necessary.",
      "Risk of kernicterus (brain damage) if left untreated. Do not delay."
    ]
  };

  return (
    <BaseAnalyzer 
      title="Jaundice Analyzer"
      themeColor="blue"
      icon={<Search />}
      mode="visual_only"
      promptTemplate={promptTemplate}
      resultLabel="Hepatic Screening"
      recommendationMap={recommendationMap}
      defectInfo="Neonatal jaundice is a common condition where a baby's skin and eyes look yellow because of high bilirubin levels. While often harmless, it occurs when a baby's liver isn't developed enough to remove bilirubin from the bloodstream."
      defectHarm="If left untreated, extremely high bilirubin levels can lead to kernicterus—a type of permanent brain damage. Severe jaundice requires phototherapy or exchange transfusion to prevent neurodevelopmental complications or hearing loss."
    />
  );
};

export default JaundiceAnalyzer;
