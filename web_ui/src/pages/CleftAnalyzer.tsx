import React from 'react';
import BaseAnalyzer from './BaseAnalyzer';
import { Baby } from 'lucide-react';

const CleftAnalyzer = () => {
  const promptTemplate = `Analyze the provided media (either a single image or temporal frames from a video) of a newborn's face for signs of Cleft Lip or Cleft Palate.
  Identify if there are any visible gaps in the upper lip or roof of the mouth.
  
  Format: JSON { diagnosis, confidence, thinking, recommendations }`;

  return (
    <BaseAnalyzer 
      title="Cleft Analyzer"
      themeColor="orange"
      icon={<Baby />}
      mode="visual_only"
      promptTemplate={promptTemplate}
      resultLabel="Structural Analysis"
      defectInfo="A cleft lip is an opening or split in the upper lip that occurs when developing facial structures in an unborn baby don't close completely. A cleft palate is a split or opening in the roof of the mouth."
      defectHarm="These structural defects can cause severe difficulty with feeding/nursing, leading to malnutrition. They also frequently cause hearing loss, frequent ear infections, and delayed speech and language development."
    />
  );
};

export default CleftAnalyzer;
