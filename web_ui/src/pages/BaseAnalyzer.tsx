import React, { useState, useRef, useEffect } from 'react';
import { Upload, Video, Music, Search, RefreshCcw, Settings, AlertCircle, CheckCircle2, Info, Activity, Camera, ArrowLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';

interface AnalysisResult {
  diagnosis: string;
  confidence: number;
  thinking: string;
  details?: string;
  observations?: string;
  recommendations: string[];
}

interface BaseAnalyzerProps {
  title: string;
  themeColor: string; // 'blue', 'red', 'purple', 'orange', 'emerald', 'cyan', 'amber', 'indigo'
  icon: React.ReactNode;
  mode: 'audio_only' | 'visual_only' | 'multimodal';
  promptTemplate: string;
  resultLabel?: string;
  defectInfo: string;
  defectHarm: string;
  staticRecommendations?: string[];
  recommendationMap?: Record<string, string[]>;
}

const BaseAnalyzer: React.FC<BaseAnalyzerProps> = ({ 
  title, 
  themeColor, 
  icon, 
  mode, 
  promptTemplate, 
  resultLabel = "Analysis Result", 
  defectInfo, 
  defectHarm,
  staticRecommendations,
  recommendationMap
}) => {
  const navigate = useNavigate();
  const [file, setFile] = useState<string | null>(null);
  const [frames, setFrames] = useState<string[]>([]);
  const [analyzing, setAnalyzing] = useState(false);
  const [result, setResult] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [hasAudio, setHasAudio] = useState<boolean | null>(null);
  const [audioBase64, setAudioBase64] = useState<string>("");
  const fileInputRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);

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

  const colorClasses: Record<string, string> = {
    blue: 'bg-blue-600 text-blue-600 border-blue-100 bg-blue-50',
    red: 'bg-rose-600 text-rose-600 border-rose-100 bg-rose-50',
    purple: 'bg-purple-600 text-purple-600 border-purple-100 bg-purple-50',
    orange: 'bg-orange-600 text-orange-600 border-orange-100 bg-orange-50',
    emerald: 'bg-emerald-600 text-emerald-600 border-emerald-100 bg-emerald-50',
    cyan: 'bg-cyan-700 text-cyan-700 border-cyan-100 bg-cyan-50',
    amber: 'bg-amber-600 text-amber-600 border-amber-100 bg-amber-50',
    indigo: 'bg-indigo-600 text-indigo-600 border-indigo-100 bg-indigo-50',
  };

  const activeColor = colorClasses[themeColor] || colorClasses.blue;
  const [bgClass, textClass, borderClass, lightBgClass] = activeColor.split(' ');

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
      videoElement.onerror = () => reject("Video load error");
    });
  };

  const processFile = async (selectedFile: File) => {
    setError(null);
    setResult(null);
    setFrames([]);

    if (selectedFile.type.startsWith('video/')) {
      const url = URL.createObjectURL(selectedFile);
      setFile(url);
      if (mode === 'multimodal' || mode === 'visual_only' || mode === 'audio_only') {
        setProcessing(true);
        try {
          if (mode !== 'audio_only') {
            const f = await extractFrames(url);
            setFrames(f);
          }
          
          if (mode === 'multimodal' || mode === 'audio_only') {
            try {
              const resp = await fetch(url);
              const ab = await resp.arrayBuffer();
              const ac = new (window.AudioContext || (window as any).webkitAudioContext)();
              const buff = await ac.decodeAudioData(ab);
              const b64 = await audioBufferToBase64Wav(buff);
              setAudioBase64(b64);
              setHasAudio(true);
            } catch (audioErr) {
              console.warn("Audio extraction failed:", audioErr);
              setHasAudio(false);
            }
          }
        } catch (err) {
          setError("Failed to process media.");
        } finally {
          setProcessing(false);
        }
      }
    } else if (selectedFile.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const base64 = e.target?.result as string;
        setFile(base64);
        setFrames([base64]);
      };
      reader.readAsDataURL(selectedFile);
    } else {
      setError("Please upload a valid video or image file.");
    }
  };

  const runAnalysis = async () => {
    if (!file) return;
    setAnalyzing(true);
    setError(null);
    setResult(null);

    try {
      let content: any[] = [{ type: "text", text: promptTemplate }];

      if (mode === 'visual_only' || mode === 'multimodal') {
        frames.forEach(f => content.push({ type: "image_url", image_url: { url: f } }));
      }

      if((mode=="multimodal" || mode === 'audio_only') && audioBase64) {
        content.push({ type: "input_audio", input_audio: { data: audioBase64, format: "wav" } });
      }

      const response = await fetch(config.host, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.api_key}`
        },
        body: JSON.stringify({
          model: config.model_name,
          messages: [
            { 
              role: "system", 
              content: "You are a specialized Neonatal Health AI assistant. Your task is to analyze media for specific birth defects or conditions. You MUST provide clinical-grade reasoning and always output valid JSON." 
            },
            { role: "user", content }
          ],
          temperature: 0.6,
          response_format: { type: "json_object" }
        })
      });

      if (!response.ok) throw new Error(`API Error: ${response.statusText}`);
      const data = await response.json();
      let aiResponse = data.choices[0].message.content;
      aiResponse = aiResponse.replace(/```json\n?|```/g, '').trim();
      setResult(JSON.parse(aiResponse));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Analysis failed.");
    } finally {
      setAnalyzing(false);
    }
  };

  let safeConfidence = 0;
  if (result && result.confidence !== undefined) {
    const parsed = parseFloat(String(result.confidence).replace(/[^0-9.]/g, ''));
    if (!isNaN(parsed)) {
      safeConfidence = parsed > 1 ? parsed / 100 : parsed;
    }
  } else if (result) {
    safeConfidence = 0.85;
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 p-4 sm:p-8">
      <header className="max-w-6xl mx-auto flex items-center justify-between mb-12">
        <div className="flex items-center gap-3">
          <button onClick={() => navigate('/')} className="p-2 hover:bg-slate-200 rounded-xl transition-colors">
            <ArrowLeft className="w-6 h-6 text-slate-500" />
          </button>
          <div className={`w-10 h-10 rounded-xl flex items-center justify-center shadow-lg ${bgClass}`}>
            {React.cloneElement(icon as React.ReactElement, { className: 'w-6 h-6 text-white' })}
          </div>
          <h1 className="text-2xl font-black tracking-tight text-slate-800">
            {title.split(' ')[0]}<span className={textClass}>{title.split(' ')[1]}</span>
          </h1>
        </div>
        <button onClick={() => navigate('/configure-llm')} className="p-3 bg-white border border-slate-200 rounded-xl hover:bg-slate-50 transition-colors shadow-sm">
          <Settings className="w-5 h-5 text-slate-500" />
        </button>
      </header>

      <div className="max-w-6xl mx-auto mb-10">
        <div className="bg-white border border-slate-200 rounded-[2.5rem] p-6 sm:p-8 flex flex-col md:flex-row gap-6 md:gap-12 items-start shadow-sm">
          <div className="flex-1">
            <h3 className={`text-sm font-black flex items-center gap-2 mb-3 uppercase tracking-widest ${textClass}`}>
              <Info className="w-4 h-4" /> What is {title.split(' ')[0]}?
            </h3>
            <p className="text-sm text-slate-600 leading-relaxed font-medium">{defectInfo}</p>
          </div>
          <div className="w-full md:w-px h-px md:h-24 bg-slate-100 shrink-0" />
          <div className="flex-1">
            <h3 className="text-sm font-black text-rose-600 flex items-center gap-2 mb-3 uppercase tracking-widest">
              <AlertCircle className="w-4 h-4" /> Potential Harm
            </h3>
            <p className="text-sm text-slate-600 leading-relaxed font-medium">{defectHarm}</p>
          </div>
        </div>
      </div>

      <main className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-start">
        <section className="space-y-6">
          <div 
            onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
            onDragLeave={() => setIsDragging(false)}
            onDrop={(e) => { e.preventDefault(); setIsDragging(false); const f = e.dataTransfer.files?.[0]; if (f) processFile(f); }}
            className={`
            relative aspect-video rounded-[2.5rem] border-2 border-dashed flex flex-col items-center justify-center transition-all overflow-hidden
            ${file ? 'border-transparent bg-white shadow-xl' : 
              isDragging ? `${borderClass} ${lightBgClass} scale-[1.02]` : 'border-slate-200 bg-white hover:border-slate-300'}
          `}>
            {file ? (
              file.startsWith('data:image/') ? (
                <img src={file} className="w-full h-full object-contain" />
              ) : (
                <video ref={videoRef} src={file} controls className="w-full h-full object-cover" />
              )
            ) : (
              <div onClick={() => fileInputRef.current?.click()} className="cursor-pointer flex flex-col items-center text-center p-8">
                <div className={`w-16 h-16 rounded-2xl flex items-center justify-center mb-4 ${lightBgClass}`}>
                  <Camera className={`w-8 h-8 ${textClass}`} />
                </div>
                <h3 className="text-xl font-black mb-2 text-slate-800">Upload Media</h3>
                <p className="text-slate-500 text-sm max-w-[280px] font-medium">
                  {mode === 'audio_only' && "Upload a video. We will extract and analyze only the audio (e.g. cry patterns)."}
                  {mode === 'visual_only' && "Upload a video or photo. We will perform detailed visual analysis."}
                  {mode === 'multimodal' && "Upload a video. We will extract 3 temporal frames and the audio track for comprehensive analysis."}
                </p>
              </div>
            )}
            {file && (
              <div className="absolute top-4 right-4 z-10">
                <button onClick={() => { setFile(null); setFrames([]); setResult(null); }} className="p-3 bg-white/90 backdrop-blur-md rounded-full hover:bg-white shadow-lg transition-colors border border-slate-100">
                  <RefreshCcw className={`w-5 h-5 ${textClass}`} />
                </button>
              </div>
            )}
          </div>

          {frames.length > 0 && (
            <div className="grid grid-cols-3 gap-3">
              {frames.map((f, i) => (
                <div key={i} className="aspect-video rounded-xl border border-slate-200 overflow-hidden bg-white shadow-sm">
                  <img src={f} className="w-full h-full object-cover" />
                </div>
              ))}
            </div>
          )}

          {file && (mode === 'audio_only' || mode === 'multimodal') && !processing && (
            <div className="flex items-center gap-4 bg-white border border-slate-200 p-4 rounded-2xl shadow-sm">
              <div className={`p-3 rounded-xl ${lightBgClass}`}>
                <Music className={`w-6 h-6 ${textClass}`} />
              </div>
              <div className="flex-1">
                <h4 className="text-sm font-bold text-slate-800">
                  {hasAudio === true ? 'Audio Track Identified' : 
                   hasAudio === false ? 'No Audio Track Found' : 'Analyzing Audio...'}
                </h4>
                <p className="text-xs text-slate-500 font-medium">
                  {hasAudio === true ? "The video's audio will be sent for acoustic analysis." : 
                   hasAudio === false ? "This video has no audio track. Only visual analysis will be performed." :
                   "Checking for baby cry patterns..."}
                </p>
              </div>
              {hasAudio !== null && <CheckCircle2 className={`w-5 h-5 ${hasAudio ? 'text-emerald-500' : 'text-amber-500'}`} />}
            </div>
          )}

          <button
            onClick={runAnalysis}
            disabled={!file || analyzing || processing}
            className={`
              w-full py-5 rounded-[1.5rem] font-black text-lg transition-all flex items-center justify-center gap-3
              ${!file || analyzing || processing 
                ? 'bg-slate-200 text-slate-400 cursor-not-allowed' 
                : 'bg-cyan-700 text-white shadow-xl shadow-cyan-700/30 hover:scale-[1.02] active:scale-95'}
            `}
          >
            {analyzing ? <RefreshCcw className="w-6 h-6 animate-spin" /> : icon}
            {analyzing ? 'Analyzing with AI...' : `Run ${title.split(' ')[0]} Analysis`}
          </button>

          {error && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 bg-rose-50 border border-rose-100 rounded-2xl flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-rose-600 shrink-0 mt-0.5" />
              <p className="text-sm text-rose-700 font-medium">{error}</p>
            </motion.div>
          )}
          <input type="file" ref={fileInputRef} onChange={(e) => { const f = e.target.files?.[0]; if (f) processFile(f); }} className="hidden" accept="video/*,image/*" />
        </section>

        <section className="space-y-6">
          <AnimatePresence mode="wait">
            {result ? (
              <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} className="bg-white border border-slate-200 rounded-[2.5rem] p-8 shadow-xl relative overflow-hidden">
                <div className="absolute top-0 right-0 p-6">
                  <div className={`p-2 rounded-full ${lightBgClass} ${textClass}`}>
                    <CheckCircle2 className="w-6 h-6" />
                  </div>
                </div>

                <div className="mb-8">
                  <span className={`text-xs font-black tracking-widest ${textClass} uppercase mb-2 block`}>{resultLabel}</span>
                  <h2 className="text-4xl font-black text-slate-800 mb-4">{result.diagnosis || result.severity || 'Analysis Complete'}</h2>
                  <div className="flex items-center gap-2">
                    <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden">
                      <motion.div initial={{ width: 0 }} animate={{ width: `${safeConfidence * 100}%` }} className={`h-full ${bgClass}`} />
                    </div>
                    <span className="text-sm font-bold text-slate-400">{Math.round(safeConfidence * 100)}% Confidence</span>
                  </div>
                </div>

                <div className="space-y-6">
                  <div className={`p-5 bg-slate-50 border border-slate-100 rounded-2xl`}>
                    <h3 className="text-sm font-black text-slate-400 uppercase tracking-widest mb-3">Reasoning</h3>
                    <p className="text-sm text-slate-600 leading-relaxed italic font-medium">"{result.thinking}"</p>
                  </div>
                  {(() => {
                    let recs = staticRecommendations;
                    if (!recs && recommendationMap && result.diagnosis) {
                      const diag = result.diagnosis.toLowerCase();
                      if (diag.includes('severe')) recs = recommendationMap.severe;
                      else if (diag.includes('moderate')) recs = recommendationMap.moderate;
                      else if (diag.includes('mild')) recs = recommendationMap.mild;
                      else if (diag.includes('normal')) recs = recommendationMap.normal;
                    }
                    if (!recs) recs = result.recommendations;
                    
                    if (recs && Array.isArray(recs)) {
                      return (
                        <div className="space-y-3">
                          <h3 className="text-sm font-black text-slate-400 uppercase tracking-widest mb-1">Recommendations</h3>
                          {recs.map((rec: string, i: number) => (
                            <div key={i} className="flex items-start gap-3 p-4 bg-slate-50 border border-slate-100 rounded-2xl text-slate-700 text-sm font-bold shadow-sm">
                              <div className={`w-1.5 h-1.5 rounded-full shrink-0 mt-2 ${bgClass}`} />
                              {rec}
                            </div>
                          ))}
                        </div>
                      );
                    }
                    return null;
                  })()}
                </div>
              </motion.div>
            ) : (
              <div className="h-full min-h-[400px] bg-white border-2 border-dashed border-slate-200 rounded-[2.5rem] flex flex-col items-center justify-center text-center p-8 text-slate-400">
                {analyzing ? (
                  <div className="space-y-6 w-full max-w-sm">
                    <div className="h-4 bg-slate-100 rounded-full w-3/4 animate-pulse mx-auto" />
                    <div className="h-32 bg-slate-100 rounded-3xl w-full animate-pulse" />
                    <div className="h-20 bg-slate-100 rounded-3xl w-full animate-pulse" />
                  </div>
                ) : (
                  <>
                    <Activity className="w-12 h-12 mb-4 text-slate-200" />
                    <h3 className="text-xl font-black mb-2 text-slate-500">No Analysis Yet</h3>
                    <p className="max-w-[280px] font-medium">Upload media to begin the AI-powered screening process.</p>
                  </>
                )}
              </div>
            )}
          </AnimatePresence>
        </section>
      </main>
    </div>
  );
};

async function audioBufferToBase64Wav(buffer: AudioBuffer): Promise<string> {
  const numOfChan = buffer.numberOfChannels;
  const length = buffer.length * numOfChan * 2 + 44;
  const outBuffer = new ArrayBuffer(length);
  const view = new DataView(outBuffer);
  let pos = 0;
  function setUint16(data: number) { view.setUint16(pos, data, true); pos += 2; }
  function setUint32(data: number) { view.setUint32(pos, data, true); pos += 4; }
  setUint32(0x46464952); setUint32(length - 8); setUint32(0x45564157);
  setUint32(0x20746d66); setUint32(16); setUint16(1); setUint16(numOfChan);
  setUint32(buffer.sampleRate); setUint32(buffer.sampleRate * 2 * numOfChan);
  setUint16(numOfChan * 2); setUint16(16); setUint32(0x61746164); setUint32(length - pos - 4);
  const channels = [];
  for (let i = 0; i < buffer.numberOfChannels; i++) channels.push(buffer.getChannelData(i));
  let offset = 0;
  while (pos < length) {
    for (let i = 0; i < numOfChan; i++) {
      let sample = Math.max(-1, Math.min(1, channels[i][offset]));
      sample = (sample < 0 ? sample * 0x8000 : sample * 0x7FFF) | 0;
      view.setInt16(pos, sample, true); pos += 2;
    }
    offset++;
  }

  const blob = new Blob([outBuffer], { type: 'audio/wav' });
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const b64 = (reader.result as string).split(',')[1];
      resolve(b64);
    };
    reader.readAsDataURL(blob);
  });
}

export default BaseAnalyzer;
