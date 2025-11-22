import { motion } from 'framer-motion';
import { useState } from 'react';

export default function BenchmarkCard({ item, gradient, index }) {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <div className="relative h-full" style={{ minHeight: '200px' }}>
      {/* Ghost Element - Maintains Layout */}
      <div className="invisible p-6 border border-transparent">
        <div className="flex items-start justify-between mb-4">
          <div className="text-4xl p-2">
            {item.emoji}
          </div>
          <div className="text-transparent">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M5 7.5L10 12.5L15 7.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
        </div>
        <h3 className="text-xl font-bold mb-3 text-transparent">
          {item.title}
        </h3>
        <p className="text-sm text-transparent leading-relaxed mb-4 line-clamp-2">
          {item.description}
        </p>
      </div>

      {/* Real Interactive Card */}
      <motion.div
        className="absolute top-0 left-0 w-full glass-effect rounded-2xl p-6 cursor-pointer hover:bg-white/5 transition-all duration-500 group overflow-hidden border border-white/10 z-10"
        whileHover={{
          y: -5,
          zIndex: 50,
          boxShadow: '0 20px 40px -10px rgba(0,0,0,0.5)'
        }}
        onMouseEnter={() => setIsExpanded(true)}
        onMouseLeave={() => setIsExpanded(false)}
      >
        {/* Gradient Glow */}
        <div className={`absolute -inset-1 bg-gradient-to-r ${gradient} opacity-0 group-hover:opacity-20 blur-xl transition-opacity duration-500`} />

        <div className="relative z-10">
          {/* Header */}
          <div className="flex items-start justify-between mb-4">
            <div className="text-4xl p-2 bg-white/5 rounded-xl backdrop-blur-sm group-hover:scale-110 transition-transform duration-300">
              {item.emoji}
            </div>
            <motion.div
              animate={{ rotate: isExpanded ? 180 : 0 }}
              className="text-white/30 group-hover:text-white/70 transition-colors"
            >
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M5 7.5L10 12.5L15 7.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </motion.div>
          </div>

          {/* Title */}
          <h3 className="text-xl font-bold mb-3 text-white group-hover:text-transparent group-hover:bg-clip-text group-hover:bg-gradient-to-r group-hover:from-white group-hover:to-gray-300 transition-all">
            {item.title}
          </h3>

          {/* Description */}
          <p className="text-sm text-gray-400 leading-relaxed mb-4 line-clamp-2 group-hover:text-gray-300 transition-colors">
            {item.description}
          </p>

          {/* Expandable content */}
          <motion.div
            initial={false}
            animate={{
              height: isExpanded ? 'auto' : 0,
              opacity: isExpanded ? 1 : 0,
              marginTop: isExpanded ? 16 : 0
            }}
            transition={{ duration: 0.3, ease: "easeInOut" }}
            className="overflow-hidden"
          >
            <div className="space-y-4 pt-4 border-t border-white/10">
              {item.thinking.length > 0 && (
                <div>
                  <h4 className="text-xs font-bold uppercase tracking-wider text-purple-400 mb-2 flex items-center gap-2">
                    <span className="w-1 h-1 rounded-full bg-purple-400"></span>
                    Thinking
                  </h4>
                  <ul className="space-y-2">
                    {item.thinking.map((think, i) => (
                      <li key={i} className="text-sm text-gray-300 flex items-start gap-2 pl-1">
                        <span className="text-purple-400/50 mt-1">›</span>
                        <span>{think}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {item.requirements.length > 0 && (
                <div>
                  <h4 className="text-xs font-bold uppercase tracking-wider text-cyan-400 mb-2 flex items-center gap-2">
                    <span className="w-1 h-1 rounded-full bg-cyan-400"></span>
                    Benchmark Metrics
                  </h4>
                  <ul className="space-y-2">
                    {item.requirements.map((req, i) => (
                      <li key={i} className="text-sm text-gray-300 flex items-start gap-2 pl-1">
                        <span className="text-cyan-400/50 mt-1">›</span>
                        <span>{req}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

            </div>
          </motion.div>
        </div>
      </motion.div>
    </div>
  );
}
