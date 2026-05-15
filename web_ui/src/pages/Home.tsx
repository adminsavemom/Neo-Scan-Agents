import React from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { 
  Search, 
  Volume2, 
  Activity, 
  Settings, 
  ChevronRight, 
  Baby, 
  Footprints, 
  Wind, 
  Stethoscope, 
  LayoutGrid,
  ShieldCheck,
  AlertTriangle,
  Bot,
  Sparkles
} from 'lucide-react';

const Home = () => {
  const navigate = useNavigate();

  const analyzers = [
    {
      title: "Jaundice AI",
      desc: "Instant skin & eye bilirubin analysis",
      icon: <Search className="w-6 h-6 text-cyan-700" />,
      path: "/jaundice-analyzer",
      color: "cyan",
      category: "Metabolic"
    },
    {
      title: "Cry Analysis",
      desc: "Decode baby's needs via audio patterns",
      icon: <Volume2 className="w-6 h-6 text-purple-600" />,
      path: "/cry-analyzer",
      color: "purple",
      category: "Acoustic"
    },
    {
      title: "Asphyxia Risk",
      desc: "Multi-modal oxygen deprivation detection",
      icon: <Activity className="w-6 h-6 text-rose-600" />,
      path: "/asphyxia-analyzer",
      color: "rose",
      category: "Critical"
    },
    {
      title: "Respiratory Distress",
      desc: "Monitor breathing patterns & RDS signs",
      icon: <Wind className="w-6 h-6 text-teal-600" />,
      path: "/rds-analyzer",
      color: "teal",
      category: "Respiratory"
    },
    {
      title: "Cleft Analyzer",
      desc: "Visual detection of lip/palate defects",
      icon: <Baby className="w-6 h-6 text-orange-600" />,
      path: "/cleft-analyzer",
      color: "orange",
      category: "Structural"
    },
    {
      title: "Clubfoot Detection",
      desc: "Limb alignment and foot positioning",
      icon: <Footprints className="w-6 h-6 text-emerald-600" />,
      path: "/clubfoot-analyzer",
      color: "emerald",
      category: "Structural"
    },
    {
      title: "Microcephaly AI",
      desc: "Head size and proportion analysis",
      icon: <LayoutGrid className="w-6 h-6 text-amber-600" />,
      path: "/microcephaly-analyzer",
      color: "amber",
      category: "Developmental"
    },
    {
      title: "Cyanosis Monitor",
      desc: "Skin oxygen saturation (SPO2) cues",
      icon: <ShieldCheck className="w-6 h-6 text-blue-600" />,
      path: "/cyanosis-analyzer",
      color: "blue",
      category: "Cardiac"
    }
  ];

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 p-6 sm:p-12 overflow-hidden relative">
      {/* Background Decor */}
      <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-cyan-600/5 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-blue-600/5 rounded-full blur-[120px] pointer-events-none" />

      <header className="max-w-7xl mx-auto flex flex-col md:flex-row md:items-center justify-between gap-6 mb-16 relative z-10">
        <div className="space-y-2">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-gradient-to-br from-cyan-600 to-cyan-700 rounded-2xl flex items-center justify-center shadow-xl shadow-cyan-600/20">
              <ShieldCheck className="w-7 h-7 text-white" />
            </div>
            <h1 className="text-3xl font-black tracking-tight text-slate-900">
              <span className="text-cyan-700">Neo Scan Agents</span>
            </h1>
          </div>
          <p className="text-slate-500 max-w-lg font-medium">
            AI-powered early detection and preventive screening for neonatal complications and birth defects.
          </p>
        </div>
        
        <div className="flex items-center gap-4">
          <button 
            onClick={() => navigate('/configure-llm')}
            className="flex items-center gap-2 px-5 py-3 bg-white border border-slate-200 rounded-2xl hover:bg-slate-50 transition-all group shadow-sm"
          >
            <Settings className="w-5 h-5 text-slate-400 group-hover:rotate-90 transition-transform" />
            <span className="text-sm font-semibold text-slate-600">AI Settings</span>
          </button>
        </div>
      </header>

      <main className="max-w-7xl mx-auto relative z-10">
        {/* Featured Agent Hero */}
        <motion.section 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          onClick={() => navigate('/agent')}
          className="mb-12 relative overflow-hidden group cursor-pointer"
        >
          <div className="absolute inset-0 bg-white rounded-[3rem] border border-slate-200 shadow-xl shadow-slate-200/50 group-hover:shadow-cyan-200/50 transition-all" />
          <div className="relative p-8 md:p-12 flex flex-col md:flex-row items-center gap-8">
            <div className="flex-1 space-y-4 text-center md:text-left">
              <div className="inline-flex items-center gap-2 px-4 py-2 bg-cyan-50 border border-cyan-100 rounded-full">
                <Sparkles className="w-4 h-4 text-cyan-600" />
                <span className="text-xs font-bold text-cyan-700 uppercase tracking-widest">New: All-in-One Analysis</span>
              </div>
              <h2 className="text-4xl md:text-5xl font-black tracking-tight leading-tight text-slate-900">
                Meet your <span className="text-cyan-700">Smart Health Agent</span>
              </h2>
              <p className="text-slate-500 text-lg max-w-xl font-medium">
                Upload a single video and let our integrated AI perform a comprehensive screening across all health modules. Chat in real-time to get personalized insights.
              </p>
              <button className="flex items-center gap-3 px-8 py-4 bg-cyan-700 text-white font-bold rounded-2xl shadow-xl shadow-cyan-700/30 hover:scale-105 active:scale-95 transition-all">
                Launch Smart Agent
                <ChevronRight className="w-5 h-5" />
              </button>
            </div>
            <div className="relative w-full md:w-1/3 aspect-video md:aspect-square rounded-[2rem] bg-slate-50 border border-slate-200 flex items-center justify-center overflow-hidden">
               <div className="absolute inset-0 bg-gradient-to-br from-cyan-100 to-transparent opacity-50" />
               <Bot className="w-24 h-24 text-cyan-700/20 animate-pulse" />
            </div>
          </div>
        </motion.section>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {analyzers.map((item, idx) => (
            <motion.div
              key={item.path}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: idx * 0.05 }}
              onClick={() => navigate(item.path)}
              className="group cursor-pointer bg-white border border-slate-200 p-6 rounded-[2.5rem] hover:border-cyan-500/50 shadow-sm hover:shadow-md transition-all hover:scale-[1.02] active:scale-95 flex flex-col justify-between min-h-[220px]"
            >
              <div>
                <div className="flex items-center justify-between mb-6">
                  <div className={`p-4 rounded-2xl bg-${item.color}-50`}>
                    {item.icon}
                  </div>
                  <span className="text-[10px] font-bold uppercase tracking-widest text-slate-400 bg-slate-50 px-3 py-1 rounded-full border border-slate-100">
                    {item.category}
                  </span>
                </div>
                <h3 className="text-xl font-bold mb-2 group-hover:text-cyan-700 transition-colors text-slate-800">{item.title}</h3>
                <p className="text-sm text-slate-500 leading-relaxed font-medium">{item.desc}</p>
              </div>
              
              <div className="mt-6 flex items-center gap-2 text-cyan-700 text-sm font-bold opacity-0 group-hover:opacity-100 transition-opacity">
                Launch Analyzer
                <ChevronRight className="w-4 h-4" />
              </div>
            </motion.div>
          ))}
        </div>

        {/* Emergency Banner */}
        <section className="mt-16 p-8 bg-rose-50 border border-rose-100 rounded-[3rem] flex flex-col md:flex-row items-center gap-8 shadow-sm">
          <div className="w-16 h-16 bg-rose-100 rounded-3xl flex items-center justify-center shrink-0">
            <AlertTriangle className="w-8 h-8 text-rose-600" />
          </div>
          <div className="flex-1 text-center md:text-left">
            <h3 className="text-xl font-bold text-rose-700 mb-1">Clinical Disclaimer</h3>
            <p className="text-slate-600 text-sm leading-relaxed max-w-2xl font-medium">
              This preventive agent is an AI screening tool designed to assist healthcare workers and parents in early identification. It is not a diagnostic replacement for specialized pediatric care. In emergencies, please contact your local medical facility immediately.
            </p>
          </div>
          <div className="flex gap-4">
            <button className="px-8 py-4 bg-rose-600 text-white font-bold rounded-2xl shadow-xl shadow-rose-600/20 hover:scale-105 active:scale-95 transition-all">
              Emergency Contacts
            </button>
          </div>
        </section>
      </main>

      {/* Footer Branding */}
      <footer className="max-w-7xl mx-auto mt-20 pt-8 border-t border-slate-200 flex justify-between items-center text-slate-400">
        <p className="text-sm font-semibold text-slate-500">© 2026 SaveMom AI Technologies</p>
        <div className="flex gap-6">
          <Stethoscope className="w-5 h-5 opacity-40" />
          <ShieldCheck className="w-5 h-5 opacity-40" />
        </div>
      </footer>
    </div>
  );
};

export default Home;
