import React, { useState, useRef, useEffect } from 'react';
import { Upload, Video, Music, Search, RefreshCcw, Settings, AlertCircle, CheckCircle2, Info, Activity, Wind, ArrowLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';

interface RDSAnalysisResult {
  severity: "none" | "mild" | "moderate" | "severe";
  confidence: number;
  thinking: string;
  visual_observations: string;
  audio_observations: string;
  recommendations: string[];
}

const RDSAnalyzer = () => {
  const navigate = useNavigate();
  const [video, setVideo] = useState<string | null>(null);
  const [frames, setFrames] = useState<string[]>([]);
  const [analyzing, setAnalyzing] = useState(false);
  const [result, setResult] = useState<RDSAnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [processingVideo, setProcessingVideo] = useState(false);
  const [hasAudio, setHasAudio] = useState<boolean | null>(null);
  const [audioBase64, setAudioBase64] = useState<string>("");
  const fileInputRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);

  const [config, setConfig] = useState({
    host: 'http://localhost:11434/v1/chat/completions',
    model_name: 'gemma4:e4b',
    api_key: 'ollama'
  });

  const staticRecommendations = {
    none: [
      "Continue regular monitoring of respiratory rate.",
      "Maintain normal feeding schedule.",
      "Ensure baby stays warm and comfortable."
    ],
    mild: [
      "Monitor respiratory rate closely (normal is 40-60 bpm).",
      "Ensure clear nasal passages to reduce work of breathing.",
      "Schedule a follow-up with a pediatrician within 24 hours.",
      "Watch for worsening retractions or grunting."
    ],
    moderate: [
      "Seek immediate medical consultation.",
      "Keep the baby in an upright or slightly elevated position.",
      "Monitor oxygen saturation if a pulse oximeter is available.",
      "Prepare for potential hospital admission for oxygen support."
    ],
    severe: [
      "EMERGENCY: Call for immediate medical assistance or go to the nearest NICU.",
      "Provide oxygen support if available immediately.",
      "Immediate hospital admission required for surfactant therapy.",
      "Do not feed by mouth to prevent aspiration risk."
    ]
  };

  useEffect(() => {
    const savedConfig = localStorage.getItem('llm_config');
    if (savedConfig) {
      try {
        setConfig(JSON.parse(savedConfig));
      } catch (e) {
        console.error("Failed to load LLM config:", e);
      }
    }
  }, []);

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
          await new Promise((res) => {
            videoElement.onseeked = res;
          });
          
          canvas.width = videoElement.videoWidth;
          canvas.height = videoElement.videoHeight;
          ctx?.drawImage(videoElement, 0, 0, canvas.width, canvas.height);
          capturedFrames.push(canvas.toDataURL('image/jpeg', 0.8));
        }
        
        videoElement.pause();
        resolve(capturedFrames);
      };

      videoElement.onerror = (e) => reject("Failed to load video for frame extraction.");
    });
  };

  const processFile = async (file: File) => {
    if (file && file.type.startsWith('video/')) {
      const url = URL.createObjectURL(file);
      setVideo(url);
      setResult(null);
      setError(null);
      setProcessingVideo(true);
      
      try {
        const extractedFrames = await extractFrames(url);
        setFrames(extractedFrames);
        
        try {
          const response = await fetch(url);
          const arrayBuffer = await response.arrayBuffer();
          const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
          const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);
          const base64 = await audioBufferToBase64Wav(audioBuffer);
          setAudioBase64(base64);
          setHasAudio(true);
        } catch (audioErr) {
          setHasAudio(false);
          setAudioBase64("");
        }
      } catch (err) {
        setError("Failed to extract frames from video.");
      } finally {
        setProcessingVideo(false);
      }
    } else if (file && file.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const base64 = e.target?.result as string;
        setVideo(base64);
        setFrames([base64]);
      };
      reader.readAsDataURL(file);
      setResult(null);
      setError(null);
    } else {
      setError("Please upload a valid video or image file.");
    }
  };

  const handleVideoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) processFile(file);
  };

  const runAnalysis = async () => {
    if (!video || frames.length === 0) return;

    setAnalyzing(true);
    setError(null);
    setResult(null);

    try {
      const visualPrompt = `Analyze these ${frames.length} temporal frames of a newborn for visual signs of Respiratory Distress Syndrome (RDS).
      Look for:
      - Nasal flaring
      - Intercostal or subcostal retractions (chest sinking during inhalation)
      - Rapid breathing or abnormal chest expansion
      
      Provide your visual findings in JSON format:
      {
        "visual_findings": "Detailed description of breathing mechanics observed",
        "severity_visual": "none/mild/moderate/severe"
      }
      Only return the JSON.`;

      const visualResponse = await fetch(config.host, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${config.api_key}` },
        body: JSON.stringify({
          model: config.model_name,
          messages: [
            { role: "system", content: "You are a specialized Neonatal Respiratory AI. Analyze visual frames for RDS risk." },
            {
              role: "user",
              content: [
                { type: "text", text: visualPrompt },
                ...frames.map(f => ({ type: "image_url", image_url: { url: f } }))
              ]
            }
          ],
          response_format: { type: "json_object" }
        })
      });

      if (!visualResponse.ok) throw new Error("Visual analysis failed.");
      const visualData = await visualResponse.json();
      const visualFindings = JSON.parse(visualData.choices[0].message.content.replace(/```json\n?|```/g, '').trim());

      const finalPrompt = `You are performing a final RDS (Respiratory Distress Syndrome) assessment.
      
      VISUAL FINDINGS FROM EARLIER STEP:
      ${visualFindings.visual_findings}
      Visual Severity Estimate: ${visualFindings.severity_visual}
      
      Now, analyze the accompanying audio for expiratory grunting or abnormal breath sounds.
      Combine the visual findings with the acoustic data to provide a definitive diagnosis.
      
      Provide the final analysis in the following JSON format:
      {
        "severity": "none/mild/moderate/severe",
        "confidence": 0.0 to 1.0,
        "thinking": "Step-by-step clinical reasoning integrating visual findings and audio patterns",
        "visual_observations": "Summarized visual data",
        "audio_observations": "Analysis of respiratory sounds"
      }
      Only return the JSON.`;

      const finalResponse = await fetch(config.host, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${config.api_key}` },
        body: JSON.stringify({
          model: config.model_name,
          messages: [
            { role: "system", content: "You are a specialized Neonatal Respiratory AI. Integrate visual and audio data for RDS diagnosis." },
            {
              role: "user",
              content: [
                { type: "text", text: finalPrompt },
                ...(audioBase64 ? [{ type: "input_audio", input_audio: { data: audioBase64, format: "wav" } }] : [])
              ]
            }
          ],
          temperature: 0.4,
          response_format: { type: "json_object" }
        })
      });

      if (!finalResponse.ok) throw new Error("Multi-modal integration failed.");

      const data = await finalResponse.json();
      let aiResponse = data.choices[0].message.content;
      aiResponse = aiResponse.replace(/```json\n?|```/g, '').trim();

      try {
        const parsed = JSON.parse(aiResponse);
        const severity = parsed.severity as keyof typeof staticRecommendations;
        parsed.recommendations = staticRecommendations[severity] || staticRecommendations.none;
        setResult(parsed);
      } catch (parseError) {
        setError("AI returned an invalid format. Please try again.");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to connect to AI host.");
    } finally {
      setAnalyzing(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 p-4 sm:p-8">
      <header className="max-w-6xl mx-auto flex items-center justify-between mb-12">
        <div className="flex items-center gap-3">
          <button onClick={() => navigate('/')} className="p-2 hover:bg-slate-200 rounded-xl transition-colors">
            <ArrowLeft className="w-6 h-6 text-slate-500" />
          </button>
          <div className="w-10 h-10 bg-cyan-700 rounded-xl flex items-center justify-center shadow-lg shadow-cyan-600/20">
            <Wind className="w-6 h-6 text-white" />
          </div>
          <h1 className="text-2xl font-black tracking-tight text-slate-800">RDS<span className="text-cyan-700">Analyzer</span></h1>
        </div>
        <div className="flex gap-4">
          <button 
            onClick={() => navigate('/configure-llm')}
            className="p-3 bg-white border border-slate-200 rounded-xl hover:bg-slate-50 transition-colors shadow-sm"
          >
            <Settings className="w-5 h-5 text-slate-500" />
          </button>
        </div>
      </header>

      <main className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-start">
        <section className="space-y-6">
          <div className="relative group">
            <div 
              onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={(e) => { e.preventDefault(); setIsDragging(false); const f = e.dataTransfer.files?.[0]; if (f) processFile(f); }}
              className={`
              aspect-video rounded-[2.5rem] border-2 border-dashed flex flex-col items-center justify-center transition-all overflow-hidden
              ${video ? 'border-transparent bg-white shadow-xl' : 
                isDragging ? 'border-cyan-700 bg-cyan-50 scale-[1.02]' : 'border-slate-200 bg-white hover:border-cyan-500/50 hover:bg-slate-50'}
            `}>
              {video ? (
                <div className="relative w-full h-full">
                  {video.startsWith('data:image/') ? (
                    <img src={video} className="w-full h-full object-contain" />
                  ) : (
                    <video ref={videoRef} src={video} controls className="w-full h-full object-cover" />
                  )}
                  <div className="absolute top-4 right-4 z-10">
                    <button 
                      onClick={() => { setVideo(null); setFrames([]); }}
                      className="p-3 bg-white/90 backdrop-blur-md rounded-full hover:bg-white shadow-lg transition-colors border border-slate-100"
                    >
                      <RefreshCcw className="w-5 h-5 text-cyan-700" />
                    </button>
                  </div>
                </div>
              ) : (
                <div 
                  onClick={() => fileInputRef.current?.click()}
                  className="cursor-pointer flex flex-col items-center text-center p-8"
                >
                  <div className="w-16 h-16 bg-cyan-50 rounded-2xl flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                    <Video className="w-8 h-8 text-cyan-700" />
                  </div>
                  <h3 className="text-xl font-black mb-2 text-slate-800">Upload Respiratory Media</h3>
                  <p className="text-slate-500 text-sm max-w-[240px] font-medium">
                    Upload a video or photo of the newborn's chest. We'll analyze breathing patterns and sounds.
                  </p>
                </div>
              )}
            </div>
            <input type="file" ref={fileInputRef} onChange={handleVideoUpload} className="hidden" accept="video/*,image/*" />
          </div>

          {frames.length > 0 && (
            <div className="grid grid-cols-3 gap-3">
              {['Start', 'Mid', 'End'].map((label, i) => (
                <div key={i} className="space-y-2">
                  <div className="aspect-video rounded-xl border border-slate-200 overflow-hidden bg-white shadow-sm">
                    <img src={frames[i]} className="w-full h-full object-cover" alt={label} />
                  </div>
                  <p className="text-[8px] text-center uppercase tracking-widest text-slate-400 font-black">{label} Frame</p>
                </div>
              ))}
            </div>
          )}

          <div className="bg-white border border-slate-200 p-6 rounded-3xl space-y-4 shadow-sm">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-teal-50 rounded-2xl">
                <Music className="w-6 h-6 text-teal-600" />
              </div>
              <div className="flex-1">
                <h4 className="font-bold text-slate-800">Processing Status</h4>
                <p className="text-sm text-slate-500 font-medium">
                  {processingVideo ? 'Extracting visual & audio signatures...' : 
                   video ? (
                     hasAudio === true ? 'Respiratory data ready.' : 
                     hasAudio === false ? 'Visual data ready (No audio track found).' :
                     'Ready for analysis.'
                   ) : 'Waiting for upload...'}
                </p>
              </div>
              {video && !processingVideo && <CheckCircle2 className={`w-5 h-5 ${hasAudio === false ? 'text-amber-500' : 'text-emerald-500'}`} />}
            </div>
          </div>

          <button
            onClick={runAnalysis}
            disabled={!video || analyzing || processingVideo}
            className={`
              w-full py-5 rounded-[1.5rem] font-black text-lg transition-all flex items-center justify-center gap-3
              ${!video || analyzing || processingVideo
                ? 'bg-slate-200 text-slate-400 cursor-not-allowed' 
                : 'bg-cyan-700 text-white shadow-xl shadow-cyan-700/30 hover:scale-[1.02] active:scale-95'}
            `}
          >
            {analyzing ? (
              <>
                <RefreshCcw className="w-6 h-6 animate-spin" />
                Analyzing Breathing Patterns...
              </>
            ) : (
              <>
                <Search className="w-6 h-6" />
                Analyze Respiratory Risk
              </>
            )}
          </button>

          {error && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="p-4 bg-rose-50 border border-rose-100 rounded-2xl flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-rose-600 shrink-0 mt-0.5" />
              <p className="text-sm text-rose-700 font-medium">{error}</p>
            </motion.div>
          )}
        </section>

        <section className="space-y-6">
          <AnimatePresence mode="wait">
            {result ? (
              <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} className="bg-white border border-slate-200 rounded-[2.5rem] p-8 shadow-xl relative overflow-hidden">
                <div className="absolute top-0 right-0 p-6">
                  <div className={`p-2 rounded-full ${result.severity === 'none' ? 'bg-emerald-50 text-emerald-600' : 'bg-cyan-50 text-cyan-700'}`}>
                    {result.severity === 'none' ? <CheckCircle2 className="w-6 h-6" /> : <AlertCircle className="w-6 h-6" />}
                  </div>
                </div>

                <div className="mb-8">
                  <span className="text-xs font-black tracking-widest text-cyan-700 uppercase mb-2 block">Detection Result</span>
                  <h2 className="text-4xl font-black text-slate-800 mb-4">
                    {result.severity.charAt(0).toUpperCase() + result.severity.slice(1)} Risk
                  </h2>
                  <div className="flex items-center gap-2">
                    <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden">
                      <motion.div initial={{ width: 0 }} animate={{ width: `${(result.confidence || 0.85) * 100}%` }} className={`h-full ${result.severity === 'none' ? 'bg-emerald-500' : 'bg-cyan-700'}`} />
                    </div>
                    <span className="text-sm font-bold text-slate-400">{Math.round((result.confidence || 0.85) * 100)}% Confidence</span>
                  </div>
                </div>

                <div className="space-y-6">
                  <div className="p-5 bg-slate-50 border border-slate-100 rounded-2xl">
                    <h3 className="text-sm font-black text-cyan-700 uppercase tracking-widest mb-3 flex items-center gap-2">
                      <Search className="w-4 h-4" />
                      Clinical Reasoning
                    </h3>
                    <p className="text-sm text-slate-600 leading-relaxed italic border-l-2 border-cyan-200 pl-4 mb-4 font-medium">
                      "{result.thinking}"
                    </p>
                    <div className="grid grid-cols-1 gap-4">
                      <div className="bg-white p-3 rounded-xl border border-slate-100 shadow-sm">
                        <p className="text-[10px] uppercase font-black text-slate-400 mb-1">Visual Observations</p>
                        <p className="text-xs text-slate-600 font-bold">{result.visual_observations}</p>
                      </div>
                      <div className="bg-white p-3 rounded-xl border border-slate-100 shadow-sm">
                        <p className="text-[10px] uppercase font-black text-slate-400 mb-1">Acoustic Observations</p>
                        <p className="text-xs text-slate-600 font-bold">{result.audio_observations}</p>
                      </div>
                    </div>
                  </div>

                  <div>
                    <h3 className="text-sm font-black text-slate-400 uppercase tracking-widest mb-3 flex items-center gap-2">
                      <Info className="w-4 h-4" />
                      Standardized Recommendations
                    </h3>
                    <ul className="grid grid-cols-1 gap-2">
                      {result.recommendations.map((rec, i) => (
                        <li key={i} className="flex items-start gap-3 p-4 bg-slate-50 rounded-2xl text-slate-700 text-sm font-bold border border-slate-100 shadow-sm">
                          <span className="w-1.5 h-1.5 rounded-full bg-cyan-700 shrink-0 mt-2" />
                          {rec}
                        </li>
                      ))}
                    </ul>
                  </div>
                </div>
              </motion.div>
            ) : (
              <div className="h-full min-h-[500px] bg-white border-2 border-dashed border-slate-200 rounded-[2.5rem] flex flex-col items-center justify-center text-center p-8 text-slate-400">
                {!analyzing && (
                  <>
                    <Wind className="w-12 h-12 mb-4 text-slate-200" />
                    <h3 className="text-xl font-black mb-2 text-slate-500">Awaiting Data</h3>
                    <p className="max-w-[280px] font-medium">Upload a video to analyze breathing mechanics and expiratory sounds.</p>
                  </>
                )}
                {analyzing && (
                  <div className="space-y-6 w-full max-w-sm">
                    <div className="h-4 bg-slate-100 rounded-full w-3/4 animate-pulse mx-auto" />
                    <div className="h-32 bg-slate-100 rounded-3xl w-full animate-pulse" />
                    <div className="h-40 bg-slate-100 rounded-3xl w-full animate-pulse" />
                  </div>
                )}
              </div>
            )}
          </AnimatePresence>

          <div className="p-6 bg-cyan-50 border border-cyan-100 rounded-2xl text-center">
            <p className="text-[10px] text-cyan-700 leading-relaxed uppercase tracking-widest font-black">
              Medical Notice: Respiratory Distress Syndrome (RDS) can progress rapidly. Always prioritize clinical observation and follow established NICU protocols.
            </p>
          </div>
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
  const channels = [];
  let offset = 0;
  let pos = 0;

  function setUint16(data: number) { view.setUint16(pos, data, true); pos += 2; }
  function setUint32(data: number) { view.setUint32(pos, data, true); pos += 4; }

  setUint32(0x46464952); setUint32(length - 8); setUint32(0x45564157);
  setUint32(0x20746d66); setUint32(16); setUint16(1); setUint16(numOfChan);
  setUint32(buffer.sampleRate); setUint32(buffer.sampleRate * 2 * numOfChan);
  setUint16(numOfChan * 2); setUint16(16); setUint32(0x61746164); setUint32(length - pos - 4);

  for (let i = 0; i < buffer.numberOfChannels; i++) channels.push(buffer.getChannelData(i));

  while (pos < length) {
    for (let i = 0; i < numOfChan; i++) {
      let sample = Math.max(-1, Math.min(1, channels[i][offset]));
      sample = (sample < 0 ? sample * 0x8000 : sample * 0x7FFF) | 0;
      view.setInt16(pos, sample, true);
      pos += 2;
    }
    offset++;
  }

  const blob = new Blob([outBuffer], { type: 'audio/wav' });
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const base64 = (reader.result as string).split(',')[1];
      resolve(base64);
    };
    reader.readAsDataURL(blob);
  });
}

export default RDSAnalyzer;
