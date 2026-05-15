import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { 
  ArrowLeft, 
  Send, 
  Video, 
  CheckCircle2, 
  Circle, 
  Loader2, 
  User, 
  Bot,
  Info,
  ShieldCheck,
  RefreshCcw,
  Sparkles,
  Activity,
  Search,
  Volume2,
  Wind,
  AlertTriangle,
  Stethoscope,
  ChevronRight,
  Baby,
  Footprints,
  LayoutGrid
} from 'lucide-react';

interface AnalysisResult {
  module: string;
  diagnosis: string;
  confidence: number;
  thinking: string;
  recommendations?: string[];
  color: string;
  icon: React.ReactNode;
}

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  result?: AnalysisResult;
  isSystem?: boolean;
}

interface AnalysisStep {
  id: string;
  label: string;
  status: 'pending' | 'processing' | 'completed' | 'error';
  description: string;
  icon: React.ReactNode;
  mode: 'visual' | 'audio' | 'multimodal';
}

const Agent = () => {
  const navigate = useNavigate();
  const [file, setFile] = useState<string | null>(null);
  const [fileName, setFileName] = useState<string | null>(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [allCompleted, setAllCompleted] = useState(false);
  const [extractedFrames, setExtractedFrames] = useState<string[]>([]);
  const [audioBase64, setAudioBase64] = useState<string | null>(null);
  
  const [steps, setSteps] = useState<AnalysisStep[]>([
    { id: 'jaundice', label: 'Jaundice', status: 'pending', description: 'Bilirubin', icon: <Search className="w-4 h-4" />, mode: 'visual' },
    { id: 'cry', label: 'Cry', status: 'pending', description: 'Acoustic', icon: <Volume2 className="w-4 h-4" />, mode: 'audio' },
    { id: 'asphyxia', label: 'Asphyxia', status: 'pending', description: 'Oxygen', icon: <Activity className="w-4 h-4" />, mode: 'multimodal' },
    { id: 'rds', label: 'RDS', status: 'pending', description: 'Breathing', icon: <Wind className="w-4 h-4" />, mode: 'multimodal' },
    { id: 'cyanosis', label: 'Cyanosis', status: 'pending', description: 'SPO2', icon: <ShieldCheck className="w-4 h-4" />, mode: 'visual' },
    { id: 'synthesis', label: 'Summary', status: 'pending', description: 'Holistic', icon: <Sparkles className="w-4 h-4" />, mode: 'multimodal' },
  ]);

  const [messages, setMessages] = useState<Message[]>([
    { 
      id: 'welcome', 
      role: 'assistant', 
      content: 'Hello! I am your AI Health Agent. Upload a video of the baby, and I will perform a systematic AI analysis across all diagnostic modules to identify any potential health issues.', 
      timestamp: new Date() 
    }
  ]);
  
  const [input, setInput] = useState('');
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const [config, setConfig] = useState({
    host: 'http://localhost:11434/v1/chat/completions',
    model_name: 'gemma4:e4b',
    api_key: 'ollama'
  });

  useEffect(() => {
    const savedConfig = localStorage.getItem('llm_config');
    if (savedConfig) {
      try { setConfig(JSON.parse(savedConfig)); } catch (e) {}
    }
  }, []);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const extractFrames = async (videoUrl: string): Promise<string[]> => {
    return new Promise((resolve, reject) => {
      const videoElement = document.createElement('video');
      videoElement.src = videoUrl;
      videoElement.crossOrigin = 'anonymous';
      videoElement.muted = true;
      videoElement.play();
      videoElement.onloadedmetadata = async () => {
        const duration = videoElement.duration;
        const times = [0.1, duration / 2, duration * 0.9];
        const capturedFrames: string[] = [];
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        for (const time of times) {
          videoElement.currentTime = time;
          await new Promise((res) => { videoElement.onseeked = res; });
          canvas.width = videoElement.videoWidth;
          canvas.height = videoElement.videoHeight;
          ctx?.drawImage(videoElement, 0, 0, canvas.width, canvas.height);
          capturedFrames.push(canvas.toDataURL('image/jpeg', 0.8));
        }
        videoElement.pause();
        resolve(capturedFrames);
      };
      videoElement.onerror = () => reject("Frame extraction failed");
    });
  };

  const extractAudio = async (videoUrl: string): Promise<string> => {
    const response = await fetch(videoUrl);
    const arrayBuffer = await response.arrayBuffer();
    const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);
    
    const numOfChan = audioBuffer.numberOfChannels;
    const length = audioBuffer.length * numOfChan * 2 + 44;
    const buffer = new ArrayBuffer(length);
    const view = new DataView(buffer);
    let pos = 0;
    const setUint16 = (d: number) => { view.setUint16(pos, d, true); pos += 2; };
    const setUint32 = (d: number) => { view.setUint32(pos, d, true); pos += 4; };
    setUint32(0x46464952); setUint32(length - 8); setUint32(0x45564157);
    setUint32(0x20746d66); setUint32(16); setUint16(1); setUint16(numOfChan);
    setUint32(audioBuffer.sampleRate); setUint32(audioBuffer.sampleRate * 2 * numOfChan);
    setUint16(numOfChan * 2); setUint16(16); setUint32(0x61746164); setUint32(length - pos - 4);
    
    for (let i = 0; i < audioBuffer.length; i++) {
      for (let channel = 0; channel < numOfChan; channel++) {
        let s = Math.max(-1, Math.min(1, audioBuffer.getChannelData(channel)[i]));
        view.setInt16(pos, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
        pos += 2;
      }
    }

    const blob = new Blob([buffer], { type: 'audio/wav' });
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        const b64 = (reader.result as string).split(',')[1];
        resolve(b64);
      };
      reader.onerror = () => reject("Audio base64 conversion failed");
      reader.readAsDataURL(blob);
    });
  };

  const performAIAnalysis = async (step: AnalysisStep, frames: string[], audio: string | null, prevResults?: string) => {
    const prompts: Record<string, string> = {
      jaundice: "Analyze these 3 temporal frames for signs of neonatal Jaundice (Icterus). CRITICAL: Look for ANY yellowish tint in skin or sclera. Keep reasoning extremely concise (max 1 sentence). Return JSON: { diagnosis, confidence, thinking }",
      cry: "Analyze the audio for baby cry patterns. Keep reasoning extremely concise (max 1 sentence). Return JSON: { diagnosis, confidence, thinking }",
      asphyxia: "Analyze for Birth Asphyxia risk markers. Keep reasoning extremely concise (max 1 sentence). Return JSON: { diagnosis, confidence, thinking }",
      rds: "Analyze for Respiratory Distress Syndrome signs. Keep reasoning extremely concise (max 1 sentence). Return JSON: { diagnosis, confidence, thinking }",
      cyanosis: "Analyze for Cyanosis. Keep reasoning extremely concise (max 1 sentence). Return JSON: { diagnosis, confidence, thinking }",
      synthesis: `Based on these previous findings: ${prevResults}. Provide a holistic clinical synthesis and integrated recommendations. Keep reasoning concise. Return JSON: { diagnosis, confidence, thinking, recommendations: [] }`
    };

    const content: any[] = [{ type: "text", text: prompts[step.id] || "Analyze for health issues." }];
    if (step.mode === 'visual' || step.mode === 'multimodal') {
      frames.forEach(f => content.push({ type: "image_url", image_url: { url: f } }));
    }
    if ((step.mode === 'audio' || step.mode === 'multimodal') && audio) {
      content.push({ type: "input_audio", input_audio: { data: audio, format: "wav" } });
    }

    try {
      const response = await fetch(config.host, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${config.api_key}` },
        body: JSON.stringify({
          model: config.model_name,
          messages: [
            { 
              role: "system", 
              content: "You are a specialized Neonatal Health AI Agent. Analyze the provided multimodal data (frames and/or audio) with high clinical sensitivity. Always return valid JSON." 
            },
            { role: "user", content }
          ],
          temperature: 0.1,
          response_format: { type: "json_object" }
        })
      });
      if (!response.ok) throw new Error("API Error");
      const data = await response.json();
      const parsed = JSON.parse(data.choices[0].message.content.replace(/```json\n?|```/g, '').trim());
      
      // Sanitize recommendations
      if (parsed.recommendations && !Array.isArray(parsed.recommendations)) {
        parsed.recommendations = [String(parsed.recommendations)];
      }
      if (!parsed.recommendations) parsed.recommendations = [];

      // Sanitize confidence
      if (parsed.confidence !== undefined) {
        let conf = parseFloat(String(parsed.confidence).replace(/[^0-9.]/g, ''));
        if (isNaN(conf)) conf = 0.85;
        parsed.confidence = conf > 1 ? conf / 100 : conf;
      } else {
        parsed.confidence = 0.85;
      }
      
      return parsed;
    } catch (err) {
      console.error(err);
      return { diagnosis: "Inconclusive", confidence: 0.5, thinking: "Analysis failed due to technical constraints.", recommendations: [] };
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0];
    if (selectedFile) processVideo(selectedFile);
  };

  const processVideo = async (videoFile: File) => {
    setFileName(videoFile.name);
    const url = URL.createObjectURL(videoFile);
    setFile(url);
    setAnalyzing(true);
    setAllCompleted(false);
    setMessages([messages[0]]);
    setSteps(prev => prev.map(s => ({ ...s, status: 'pending' })));

    try {
      const [frames, audio] = await Promise.all([
        extractFrames(url),
        extractAudio(url).catch(() => null)
      ]);
      setExtractedFrames(frames);
      setAudioBase64(audio);
      runAgentFlow(frames, audio);
    } catch (err) {
      addMessage({ role: 'assistant', content: 'Failed to process video media.' });
      setAnalyzing(false);
    }
  };

  const addMessage = (msg: Omit<Message, 'id' | 'timestamp'>) => {
    const newMsg: Message = { ...msg, id: Math.random().toString(36).substring(7), timestamp: new Date() };
    setMessages(prev => [...prev, newMsg]);
    return newMsg.id;
  };

  const updateStep = (id: string, status: AnalysisStep['status']) => {
    setSteps(prev => prev.map(s => s.id === id ? { ...s, status } : s));
  };

  const runAgentFlow = async (frames: string[], audio: string | null) => {
    const moduleColors: Record<string, string> = {
      jaundice: 'cyan', cry: 'purple', asphyxia: 'rose', rds: 'teal', cyanosis: 'blue', synthesis: 'emerald'
    };

    const accumulatedResults: string[] = [];

    for (const step of steps) {
      if (step.id === 'synthesis') continue;

      updateStep(step.id, 'processing');
      const msgId = addMessage({ role: 'assistant', content: `Running AI ${step.label}...`, isSystem: true });
      
      const aiResult = await performAIAnalysis(step, frames, audio);
      accumulatedResults.push(`${step.label}: ${aiResult.diagnosis} (${aiResult.thinking})`);
      
      const result: AnalysisResult = {
        module: step.label,
        diagnosis: aiResult.diagnosis || "Normal",
        confidence: aiResult.confidence || 0.85,
        thinking: aiResult.thinking || "Analysis complete.",
        recommendations: Array.isArray(aiResult.recommendations) ? aiResult.recommendations : [],
        color: moduleColors[step.id] || 'cyan',
        icon: step.icon
      };

      setMessages(prev => prev.map(m => m.id === msgId ? { ...m, result, content: '', isSystem: false } : m));
      updateStep(step.id, 'completed');
      await new Promise(r => setTimeout(r, 600));
    }

    updateStep('synthesis', 'processing');
    const synthId = addMessage({ role: 'assistant', content: 'Synthesizing holistic health report...', isSystem: true });
    const finalResult = await performAIAnalysis(steps.find(s => s.id === 'synthesis')!, frames, audio, accumulatedResults.join("; "));
    
    setMessages(prev => prev.map(m => m.id === synthId ? { 
      ...m, 
      content: finalResult.thinking || "Screening complete.", 
      result: {
        module: 'Final Summary',
        diagnosis: finalResult.diagnosis || 'Overall Healthy',
        confidence: finalResult.confidence || 0.95,
        thinking: finalResult.thinking || 'All systems evaluated.',
        recommendations: Array.isArray(finalResult.recommendations) ? finalResult.recommendations : ['Routine monitoring recommended.'],
        color: 'emerald',
        icon: <Sparkles className="w-5 h-5" />
      },
      isSystem: false 
    } : m));

    updateStep('synthesis', 'completed');
    setAnalyzing(false);
    setAllCompleted(true);
  };

  const handleSendMessage = async () => {
    if (!input.trim() || analyzing) return;
    const userText = input;
    setInput('');
    addMessage({ role: 'user', content: userText });
    const typingId = addMessage({ role: 'assistant', content: '...', isSystem: true });
    
    // Build context-aware chat history
    const chatHistory = messages
      .filter(m => !m.isSystem)
      .map(m => {
        let content = m.content;
        if (m.result) {
          content = `[${m.result.module} Analysis] Result: ${m.result.diagnosis}. Reasoning: ${m.result.thinking}. Recommendations: ${m.result.recommendations.join("; ")}`;
        }
        return { role: m.role, content };
      });

    // Extract final synthesis for explicit context if available
    const synthesis = messages.find(m => m.result?.module === 'Final Summary')?.result;
    const contextPrefix = synthesis 
      ? `[CONTEXT: Final Screening Summary: ${synthesis.diagnosis}. Integrated Recommendations: ${synthesis.recommendations.join("; ")}] `
      : "";

    try {
      const response = await fetch(config.host, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${config.api_key}` },
        body: JSON.stringify({
          model: config.model_name,
          messages: [
            { role: "system", content: "You are a professional Neonatal Health AI. Answer user questions accurately based on the screening results provided. Be supportive but clinically precise. If asked for medical advice, always refer back to the generated recommendations." },
            ...chatHistory,
            { role: "user", content: contextPrefix + userText }
          ],
        })
      });
      if (response.ok) {
        const data = await response.json();
        setMessages(prev => prev.map(m => m.id === typingId ? { ...m, content: data.choices[0].message.content, isSystem: false } : m));
      } else throw new Error();
    } catch {
      setMessages(prev => prev.map(m => m.id === typingId ? { ...m, content: "I'm currently having trouble processing your query. Please refer to the clinical summary and recommendations provided above.", isSystem: false } : m));
    }
  };

  return (
    <div className="flex flex-col h-screen bg-slate-50 text-slate-900 overflow-hidden font-sans">
      <header className="h-20 shrink-0 bg-white/80 backdrop-blur-2xl border-b border-slate-200 flex items-center justify-between px-8 z-30 shadow-sm">
        <div className="flex items-center gap-6">
          <button onClick={() => navigate('/')} className="p-3 hover:bg-slate-100 rounded-2xl transition-all border border-transparent hover:border-slate-200">
            <ArrowLeft className="w-5 h-5 text-slate-500" />
          </button>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-tr from-cyan-600 to-cyan-700 rounded-xl flex items-center justify-center shadow-lg shadow-cyan-600/20">
              <Sparkles className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-xl font-bold tracking-tight">Smart Health <span className="text-cyan-700">Agent</span></h1>
              <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">Neonatal Preventive Screening</p>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <div className="hidden md:flex flex-col items-end mr-4">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Status</span>
            <span className="text-xs font-semibold text-emerald-600 flex items-center gap-1.5">
              <div className="w-1.5 h-1.5 bg-emerald-500 rounded-full animate-pulse" />
              Live Diagnostics
            </span>
          </div>
          <button onClick={() => navigate('/configure-llm')} className="p-3 bg-white border border-slate-200 rounded-2xl hover:bg-slate-50 transition-all shadow-sm">
            <Activity className="w-5 h-5 text-slate-500" />
          </button>
        </div>
      </header>

      <div className="flex-1 flex overflow-hidden">
        <aside className="w-[420px] bg-white border-r border-slate-200 flex flex-col z-20">
          <div className="p-8 space-y-10 overflow-y-auto flex-1 custom-scrollbar">
            <section className="space-y-4">
              <div 
                onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
                onDragLeave={() => setIsDragging(false)}
                onDrop={(e) => { e.preventDefault(); setIsDragging(false); const f = e.dataTransfer.files?.[0]; if (f) processVideo(f); }}
                className={`relative aspect-[4/3] rounded-[2.5rem] border-2 border-dashed flex flex-col items-center justify-center transition-all overflow-hidden ${file ? 'border-transparent bg-slate-50 ring-1 ring-slate-200' : isDragging ? 'border-cyan-600 bg-cyan-50 scale-[1.02]' : 'border-slate-200 bg-slate-50/50 hover:border-slate-300'}`}
              >
                {file ? <video src={file} controls className="w-full h-full object-cover" /> : (
                  <div onClick={() => fileInputRef.current?.click()} className="cursor-pointer flex flex-col items-center text-center p-8 group">
                    <div className="w-16 h-16 rounded-[1.5rem] bg-cyan-50 border border-cyan-100 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                      <Video className="w-8 h-8 text-cyan-700" />
                    </div>
                    <h3 className="text-base font-bold mb-2 text-slate-800">Upload Baby Video</h3>
                    <p className="text-xs text-slate-500 max-w-[200px] leading-relaxed font-medium">Drop a video to start the automated clinical screening</p>
                  </div>
                )}
                <input type="file" ref={fileInputRef} onChange={handleFileUpload} className="hidden" accept="video/*" />
              </div>
              {file && (
                <div className="flex items-center justify-between px-2">
                  <div className="flex flex-col"><span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Active Source</span><span className="text-xs text-slate-600 font-bold truncate max-w-[200px]">{fileName}</span></div>
                  <button onClick={() => { setFile(null); setAllCompleted(false); setMessages([messages[0]]); }} className="p-2 hover:bg-slate-100 rounded-xl text-cyan-700 transition-colors"><RefreshCcw className="w-4 h-4" /></button>
                </div>
              )}
            </section>

            <section className="space-y-6">
              <div className="flex items-center justify-between px-1">
                <h3 className="text-[11px] font-black text-slate-400 uppercase tracking-[0.2em] flex items-center gap-2"><Activity className="w-4 h-4 text-cyan-600" />Live Pipeline</h3>
                {analyzing && <span className="text-[10px] font-bold text-cyan-600 animate-pulse">Running...</span>}
              </div>
              <div className="grid grid-cols-3 gap-3">
                {steps.map((step, index) => (
                  <motion.div 
                    key={step.id} 
                    initial={false}
                    animate={{ 
                      x: step.status === 'completed' ? [0, 5, 0] : 0,
                      scale: step.status === 'processing' ? [1, 1.05, 1] : 1
                    }}
                    transition={{ 
                      duration: 0.5,
                      repeat: step.status === 'processing' ? Infinity : 0 
                    }}
                    className={`
                      relative group flex flex-col items-center justify-center p-4 rounded-3xl border transition-all
                      ${step.status === 'completed' ? 'bg-emerald-50 border-emerald-100 text-emerald-600' : 
                        step.status === 'processing' ? 'bg-cyan-50 border-cyan-200 text-cyan-700 ring-4 ring-cyan-50' : 
                        'bg-slate-50 border-slate-100 text-slate-400'}
                    `}
                  >
                    <div className="mb-2">
                      {step.status === 'completed' ? <CheckCircle2 className="w-5 h-5" /> : 
                       step.status === 'processing' ? <Loader2 className="w-5 h-5 animate-spin" /> : 
                       step.icon}
                    </div>
                    <span className="text-[10px] font-bold tracking-tight uppercase">{step.label}</span>
                    {step.status === 'processing' && (
                      <motion.div 
                        layoutId="active-step"
                        className="absolute inset-0 border-2 border-cyan-600 rounded-3xl"
                        transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
                      />
                    )}
                  </motion.div>
                ))}
              </div>
            </section>
          </div>
        </aside>

        <main className="flex-1 flex flex-col bg-slate-50 relative">
          <div className="absolute top-0 right-0 w-[50%] h-[50%] bg-cyan-600/5 rounded-full blur-[120px] pointer-events-none" />
          <div className="flex-1 overflow-y-auto p-8 space-y-10 custom-scrollbar relative z-10">
            <AnimatePresence initial={false}>
              {messages.map((m) => (
                <motion.div key={m.id} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                  <div className={`flex gap-5 max-w-[85%] ${m.role === 'user' ? 'flex-row-reverse' : 'flex-row'}`}>
                    <div className={`w-12 h-12 shrink-0 rounded-2xl flex items-center justify-center shadow-md ${m.role === 'assistant' ? 'bg-white border border-slate-200 text-cyan-700' : 'bg-cyan-700 text-white'}`}>{m.role === 'assistant' ? <Bot className="w-7 h-7" /> : <User className="w-7 h-7" />}</div>
                    <div className="space-y-3">
                      {m.content && !m.isSystem && (
                        <div className={`p-6 rounded-[2rem] shadow-sm ${m.role === 'assistant' ? 'bg-white text-slate-800 rounded-tl-none border border-slate-200' : 'bg-cyan-700 text-white rounded-tr-none shadow-cyan-700/20'}`}>
                          <div className="text-sm leading-relaxed font-medium">
                            <ReactMarkdown 
                              remarkPlugins={[remarkGfm]}
                              components={{
                                p: ({node, ...props}) => <p className="mb-2 last:mb-0 whitespace-pre-wrap" {...props} />,
                                ul: ({node, ...props}) => <ul className="list-disc ml-4 mb-2" {...props} />,
                                ol: ({node, ...props}) => <ol className="list-decimal ml-4 mb-2" {...props} />,
                                li: ({node, ...props}) => <li className="mb-1" {...props} />,
                                strong: ({node, ...props}) => <strong className="font-black" {...props} />,
                                code: ({node, ...props}) => <code className={`${m.role === 'assistant' ? 'bg-slate-100 text-slate-800' : 'bg-cyan-800 text-cyan-50'} px-1 rounded text-xs`} {...props} />,
                              }}
                            >
                              {m.content}
                            </ReactMarkdown>
                          </div>
                        </div>
                      )}
                      {m.isSystem && m.content !== '...' && (
                        <div className="flex items-center gap-3 px-4 py-2 bg-white/50 border border-slate-200 rounded-full">
                          <Loader2 className="w-3 h-3 animate-spin text-cyan-700" />
                          <span className="text-[11px] font-bold text-slate-500 italic uppercase tracking-wider">{m.content}</span>
                        </div>
                      )}
                      {m.content === '...' && (
                        <div className="flex gap-1.5 p-4 bg-white rounded-2xl border border-slate-200 w-16 items-center justify-center"><div className="w-1.5 h-1.5 bg-cyan-600 rounded-full animate-bounce [animation-delay:-0.3s]" /><div className="w-1.5 h-1.5 bg-cyan-600 rounded-full animate-bounce [animation-delay:-0.15s]" /><div className="w-1.5 h-1.5 bg-cyan-600 rounded-full animate-bounce" /></div>
                      )}
                      {m.result && (
                        <motion.div initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className={`overflow-hidden rounded-[2.5rem] border border-slate-200 bg-white shadow-xl min-w-[420px]`}>
                          <div className={`h-2 bg-gradient-to-r ${
                            m.result.color === 'cyan' ? 'from-cyan-600 to-cyan-700' : 
                            m.result.color === 'purple' ? 'from-purple-600 to-violet-600' : 
                            m.result.color === 'rose' ? 'from-rose-600 to-pink-600' : 
                            m.result.color === 'teal' ? 'from-teal-600 to-emerald-600' : 
                            m.result.color === 'blue' ? 'from-blue-600 to-indigo-600' : 
                            'from-emerald-600 to-teal-600'}`} 
                          />
                          <div className="p-8">
                            <div className="flex items-center justify-between mb-6">
                              <div className="flex items-center gap-4">
                                <div className={`w-12 h-12 rounded-2xl flex items-center justify-center bg-${m.result.color}-50 text-${m.result.color}-700 border border-${m.result.color}-100`}>{m.result.icon}</div>
                                <div><h3 className="text-lg font-black text-slate-800">{m.result.module} Screening</h3><div className="flex items-center gap-2"><div className="w-2 h-2 bg-emerald-500 rounded-full" /><span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Diagnostic Report</span></div></div>
                              </div>
                              <div className="text-right"><span className={`text-2xl font-black text-${m.result.color}-700`}>{Math.round((m.result.confidence || 0) * 100)}%</span><p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Confidence</p></div>
                            </div>
                            <div className="bg-slate-50 rounded-3xl p-5 mb-6 border border-slate-100"><h4 className="text-xl font-black text-slate-800 mb-2">{m.result.diagnosis}</h4><p className="text-sm text-slate-600 leading-relaxed italic font-medium">"{m.result.thinking}"</p></div>
                            {m.result.recommendations && m.result.recommendations.length > 0 && (
                              <div className="space-y-3">
                                <h5 className="text-[10px] font-black text-slate-400 uppercase tracking-[0.2em] mb-2 px-1">Recommendations</h5>
                                {m.result.recommendations.map((rec, i) => (
                                  <div key={i} className="flex items-start gap-4 p-4 bg-slate-50 rounded-2xl border border-slate-100 group hover:border-cyan-200 transition-colors shadow-sm"><div className={`w-2 h-2 rounded-full mt-1.5 shrink-0 bg-${m.result.color}-600`} /><span className="text-sm text-slate-700 font-bold leading-relaxed">{rec}</span></div>
                                ))}
                              </div>
                            )}
                          </div>
                        </motion.div>
                      )}
                    </div>
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
            <div ref={messagesEndRef} />
          </div>

          <div className="p-8 border-t border-slate-200 bg-white/80 backdrop-blur-3xl z-20">
            <div className="max-w-4xl mx-auto space-y-6">
              <div className="relative group">
                <textarea
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSendMessage(); } }}
                  placeholder={analyzing ? "Agent is analyzing..." : "Ask a question about the screening results..."}
                  disabled={analyzing}
                  className="w-full bg-slate-50 border border-slate-200 rounded-[2.2rem] p-6 pr-20 text-sm focus:outline-none focus:ring-4 focus:ring-cyan-500/10 focus:border-cyan-500/30 transition-all resize-none min-h-[76px] placeholder:text-slate-400 font-medium"
                  rows={1}
                />
                <button onClick={handleSendMessage} disabled={!input.trim() || analyzing} className={`absolute right-4 bottom-4 p-4 rounded-2xl transition-all ${input.trim() && !analyzing ? 'bg-cyan-700 text-white shadow-xl shadow-cyan-700/30 hover:scale-105 active:scale-95' : 'bg-slate-200 text-slate-400'}`}><Send className="w-5 h-5" /></button>
              </div>
            </div>
          </div>
        </main>
      </div>
      <style>{`.custom-scrollbar::-webkit-scrollbar { width: 4px; } .custom-scrollbar::-webkit-scrollbar-track { background: transparent; } .custom-scrollbar::-webkit-scrollbar-thumb { background: #e2e8f0; border-radius: 10px; } .custom-scrollbar::-webkit-scrollbar-thumb:hover { background: #cbd5e1; }`}</style>
    </div>
  );
};

export default Agent;
