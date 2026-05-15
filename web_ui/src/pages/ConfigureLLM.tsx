import React, { useState, useEffect } from 'react';
import { Save, Settings, Server, Key, Box, ChevronLeft } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const ConfigureLLM = () => {
  const navigate = useNavigate();
  const [config, setConfig] = useState({
    host: 'http://localhost:11434/v1/chat/completions',
    model_name: 'gemma4:e4b',
    api_key: 'ollama'
  });

  const [saved, setSaved] = useState(false);

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

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    localStorage.setItem('llm_config', JSON.stringify(config));
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 p-4 sm:p-8 flex items-center justify-center relative overflow-hidden">
      {/* Background Subtle Gradients */}
      <div className="absolute top-0 -left-20 w-96 h-96 bg-cyan-100/50 rounded-full blur-[100px]"></div>
      <div className="absolute bottom-0 -right-20 w-96 h-96 bg-blue-100/50 rounded-full blur-[100px]"></div>

      <div className="max-w-md w-full relative">
        <button 
          onClick={() => navigate('/')}
          className="flex items-center gap-2 text-slate-500 hover:text-cyan-700 mb-8 transition-colors group font-bold"
        >
          <ChevronLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
          Back to Dashboard
        </button>

        <div className="bg-white border border-slate-200 rounded-[2.5rem] p-8 shadow-xl">
          <div className="flex items-center gap-3 mb-8">
            <div className="p-3 bg-cyan-50 rounded-2xl">
              <Settings className="w-6 h-6 text-cyan-700" />
            </div>
            <div>
              <h1 className="text-2xl font-black text-slate-800">
                LLM Settings
              </h1>
              <p className="text-slate-500 text-sm font-medium">Configure your AI diagnostic engine</p>
            </div>
          </div>

          <form onSubmit={handleSave} className="space-y-6">
            <div className="space-y-2">
              <label className="text-xs font-black text-slate-400 flex items-center gap-2 uppercase tracking-widest">
                <Server className="w-4 h-4" />
                Host Endpoint
              </label>
              <input
                type="text"
                value={config.host}
                onChange={(e) => setConfig({ ...config, host: e.target.value })}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl px-4 py-3 focus:outline-none focus:ring-2 focus:ring-cyan-700/20 transition-all text-slate-800 font-bold"
                placeholder="http://localhost:11434/v1/chat/completions"
              />
            </div>

            <div className="space-y-2">
              <label className="text-xs font-black text-slate-400 flex items-center gap-2 uppercase tracking-widest">
                <Box className="w-4 h-4" />
                Model Name
              </label>
              <input
                type="text"
                value={config.model_name}
                onChange={(e) => setConfig({ ...config, model_name: e.target.value })}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl px-4 py-3 focus:outline-none focus:ring-2 focus:ring-cyan-700/20 transition-all text-slate-800 font-bold"
                placeholder="gemma4:e4b"
              />
            </div>

            <div className="space-y-2">
              <label className="text-xs font-black text-slate-400 flex items-center gap-2 uppercase tracking-widest">
                <Key className="w-4 h-4" />
                API Key
              </label>
              <input
                type="password"
                value={config.api_key}
                onChange={(e) => setConfig({ ...config, api_key: e.target.value })}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl px-4 py-3 focus:outline-none focus:ring-2 focus:ring-cyan-700/20 transition-all text-slate-800 font-bold"
                placeholder="ollama"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-cyan-700 hover:bg-cyan-800 text-white font-black py-4 rounded-xl shadow-lg shadow-cyan-700/20 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
            >
              <Save className="w-5 h-5" />
              {saved ? 'Settings Saved!' : 'Save Configuration'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default ConfigureLLM;
