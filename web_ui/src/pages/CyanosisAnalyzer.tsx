import React from 'react';
import BaseAnalyzer from './BaseAnalyzer';
import { ShieldCheck } from 'lucide-react';

const CyanosisAnalyzer = () => {
  const promptTemplate = `Analyze the provided media (either a single image or temporal frames from a video) and any available audio from a newborn for signs of Cyanosis (bluish skin or lips).
  Look for:
  - Persistent blue/gray discoloration in the lips, tongue, or extremities.
  - Changes in skin tone if video is provided.
  
  Format: JSON { diagnosis, confidence, thinking, recommendations }`;

  return (
    <BaseAnalyzer 
      title="Cyanosis Analyzer"
      themeColor="indigo"
      icon={<ShieldCheck />}
      mode="multimodal"
      promptTemplate={promptTemplate}
      resultLabel="Circulatory Analysis"
      defectInfo="Cyanosis refers to a bluish cast to the skin and mucous membranes. In newborns, central cyanosis (affecting the core, lips, and tongue) indicates that the blood circulating through the body is not fully oxygenated."
      defectHarm="Central cyanosis is often a critical sign of underlying congenital heart disease (e.g., Tetralogy of Fallot) or severe respiratory problems. It requires immediate emergency medical evaluation to prevent brain damage or death from hypoxia."
    />
  );
};

export default CyanosisAnalyzer;
