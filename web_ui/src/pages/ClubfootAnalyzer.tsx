import React from 'react';
import BaseAnalyzer from './BaseAnalyzer';
import { Footprints } from 'lucide-react';

const ClubfootAnalyzer = () => {
  const promptTemplate = `Analyze the provided media (either a single image or temporal frames from a video) of a newborn's feet for signs of Clubfoot (Talipes Equinovarus).
  Look for inward or downward rotation of the feet and limited range of motion cues.
  
  Format: JSON { diagnosis, confidence, thinking, recommendations }`;

  return (
    <BaseAnalyzer 
      title="Clubfoot Analyzer"
      themeColor="emerald"
      icon={<Footprints />}
      mode="visual_only"
      promptTemplate={promptTemplate}
      resultLabel="Orthopedic Analysis"
      defectInfo="Clubfoot is a structural congenital deformity where a baby's foot is twisted out of shape or position. The tissues connecting the muscles to the bone (tendons) are shorter than usual."
      defectHarm="If left untreated, a clubfoot will not improve and the child will grow to walk on the outer edge of their foot, leading to chronic pain, severe mobility limitations, inability to wear normal shoes, and debilitating arthritis later in life."
    />
  );
};

export default ClubfootAnalyzer;
