import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Home from './pages/Home';
import JaundiceAnalyzer from './pages/JaundiceAnalyzer';
import ConfigureLLM from './pages/ConfigureLLM';
import CryAnalyzer from './pages/CryAnalyzer';
import AsphyxiaAnalyzer from './pages/AsphyxiaAnalyzer';
import RDSAnalyzer from './pages/RDSAnalyzer';
import CleftAnalyzer from './pages/CleftAnalyzer';
import ClubfootAnalyzer from './pages/ClubfootAnalyzer';
import MicrocephalyAnalyzer from './pages/MicrocephalyAnalyzer';
import CyanosisAnalyzer from './pages/CyanosisAnalyzer';
import Agent from './pages/Agent';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/agent" element={<Agent />} />
        <Route path="/jaundice-analyzer" element={<JaundiceAnalyzer />} />
        <Route path="/cry-analyzer" element={<CryAnalyzer />} />
        <Route path="/asphyxia-analyzer" element={<AsphyxiaAnalyzer />} />
        <Route path="/rds-analyzer" element={<RDSAnalyzer />} />
        <Route path="/cleft-analyzer" element={<CleftAnalyzer />} />
        <Route path="/clubfoot-analyzer" element={<ClubfootAnalyzer />} />
        <Route path="/microcephaly-analyzer" element={<MicrocephalyAnalyzer />} />
        <Route path="/cyanosis-analyzer" element={<CyanosisAnalyzer />} />
        <Route path="/configure-llm" element={<ConfigureLLM />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Router>
  );
}

export default App;
