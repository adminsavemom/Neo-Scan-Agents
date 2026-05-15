import React from 'react';
import BaseAnalyzer from './BaseAnalyzer';
import { LayoutGrid } from 'lucide-react';

const MicrocephalyAnalyzer = () => {
  const promptTemplate = `Analyze the provided media (either a single image or temporal frames from a video) of a newborn for signs of Microcephaly.
  Evaluate the head size relative to the body and typical neonatal proportions.
  
  Format: JSON { diagnosis, confidence, thinking, recommendations }`;

  return (
    <BaseAnalyzer 
      title="Microcephaly Analyzer"
      themeColor="amber"
      icon={<LayoutGrid />}
      mode="visual_only"
      promptTemplate={promptTemplate}
      resultLabel="Growth Analysis"
      defectInfo="Microcephaly is a condition where a baby's head is significantly smaller than expected, often because the baby's brain has not developed properly during pregnancy or has stopped growing after birth."
      defectHarm="Microcephaly can be linked to severe developmental delays, intellectual disability, seizures, problems with movement and balance, hearing loss, and vision problems. Early detection is critical to provide supportive therapies."
    />
  );
};

export default MicrocephalyAnalyzer;
