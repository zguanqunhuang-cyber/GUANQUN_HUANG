import { motion } from 'framer-motion';
import { useState, useRef, useEffect } from 'react';

const categoryLabels = {
  'vitality': '生命力',
  'interest': '有趣',
  'consciousness': '人类',
  'myself': '我',
  'truth': '真理'
};

export default function CategoryNav({ categories, activeCategory, onCategoryChange }) {
  const [mouseX, setMouseX] = useState(null);
  const [hoveredIndex, setHoveredIndex] = useState(null);
  const [buttonPositions, setButtonPositions] = useState([]);
  const [pulseSignals, setPulseSignals] = useState([]);
  const navRef = useRef(null);
  const buttonRefs = useRef([]);

  useEffect(() => {
    buttonRefs.current = buttonRefs.current.slice(0, categories.length);
  }, [categories]);

  // 计算按钮位置用于绘制连接线
  useEffect(() => {
    const updatePositions = () => {
      if (navRef.current) {
        const navRect = navRef.current.getBoundingClientRect();
        const positions = buttonRefs.current.map((btn) => {
          if (!btn) return null;
          const rect = btn.getBoundingClientRect();
          return {
            x: rect.left - navRect.left + rect.width / 2,
            y: rect.top - navRect.top + rect.height / 2,
          };
        }).filter(Boolean);
        setButtonPositions(positions);
      }
    };

    updatePositions();
    window.addEventListener('resize', updatePositions);
    return () => window.removeEventListener('resize', updatePositions);
  }, [categories]);

  // 定期发送神经信号脉冲
  useEffect(() => {
    const interval = setInterval(() => {
      if (buttonPositions.length > 1) {
        const randomPair = Math.floor(Math.random() * (buttonPositions.length - 1));
        setPulseSignals(prev => [...prev, {
          id: Date.now(),
          from: randomPair,
          to: randomPair + 1,
          progress: 0
        }]);
      }
    }, 2000);

    return () => clearInterval(interval);
  }, [buttonPositions]);

  // 更新脉冲动画
  useEffect(() => {
    if (pulseSignals.length === 0) return;

    const animation = setInterval(() => {
      setPulseSignals(prev =>
        prev.map(signal => ({
          ...signal,
          progress: signal.progress + 0.02
        })).filter(signal => signal.progress < 1)
      );
    }, 16);

    return () => clearInterval(animation);
  }, [pulseSignals.length]);

  const handleMouseMove = (e) => {
    if (navRef.current) {
      const rect = navRef.current.getBoundingClientRect();
      setMouseX(e.clientX - rect.left);
    }
  };

  const handleMouseLeave = () => {
    setMouseX(null);
  };

  const calculateScale = (buttonIndex) => {
    if (mouseX === null || !buttonRefs.current[buttonIndex]) return 1;

    const buttonRect = buttonRefs.current[buttonIndex].getBoundingClientRect();
    const navRect = navRef.current.getBoundingClientRect();
    const buttonCenter = buttonRect.left - navRect.left + buttonRect.width / 2;
    const distance = Math.abs(mouseX - buttonCenter);

    // 放大效果：距离越近，放大越明显
    const maxScale = 1.5;
    const minScale = 1;
    const effectRange = 150; // 影响范围（像素）

    if (distance < effectRange) {
      const scale = maxScale - ((distance / effectRange) * (maxScale - minScale));
      return scale;
    }

    return minScale;
  };

  return (
    <nav className="fixed bottom-8 left-1/2 transform -translate-x-1/2 z-50">
      <motion.div
        ref={navRef}
        className="glass-effect rounded-full px-4 py-3 backdrop-blur-2xl bg-black/40 border border-white/10 shadow-2xl relative"
        initial={{ y: 100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.5, type: "spring", stiffness: 200 }}
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
      >
        {/* 神经元连接线 SVG 层 */}
        {buttonPositions.length > 0 && (
          <svg
            className="absolute inset-0 w-full h-full pointer-events-none"
            style={{ overflow: 'visible' }}
          >
            <defs>
              {/* 发光滤镜 */}
              <filter id="glow">
                <feGaussianBlur stdDeviation="2" result="coloredBlur"/>
                <feMerge>
                  <feMergeNode in="coloredBlur"/>
                  <feMergeNode in="SourceGraphic"/>
                </feMerge>
              </filter>
              {/* 渐变 */}
              <linearGradient id="connectionGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stopColor="rgba(139, 92, 246, 0.3)" />
                <stop offset="50%" stopColor="rgba(236, 72, 153, 0.3)" />
                <stop offset="100%" stopColor="rgba(139, 92, 246, 0.3)" />
              </linearGradient>
            </defs>

            {/* 绘制所有连接线 */}
            {buttonPositions.map((pos, i) => {
              if (i === buttonPositions.length - 1) return null;
              const nextPos = buttonPositions[i + 1];
              const isActive = activeCategory === categories[i]?.id || activeCategory === categories[i + 1]?.id;
              const isHovered = hoveredIndex === i || hoveredIndex === i + 1;

              return (
                <g key={`connection-${i}`}>
                  {/* 主连接线 */}
                  <motion.line
                    x1={pos.x}
                    y1={pos.y}
                    x2={nextPos.x}
                    y2={nextPos.y}
                    stroke="url(#connectionGradient)"
                    strokeWidth={isActive ? "2" : "1"}
                    filter="url(#glow)"
                    initial={{ pathLength: 0, opacity: 0 }}
                    animate={{
                      pathLength: 1,
                      opacity: isActive ? 0.8 : isHovered ? 0.6 : 0.3,
                      strokeWidth: isActive ? 2 : isHovered ? 1.5 : 1
                    }}
                    transition={{ duration: 0.8, delay: i * 0.1 }}
                  />

                  {/* 连接点 */}
                  <motion.circle
                    cx={pos.x}
                    cy={pos.y}
                    r={isActive ? "3" : "2"}
                    fill="rgba(139, 92, 246, 0.6)"
                    filter="url(#glow)"
                    initial={{ scale: 0 }}
                    animate={{
                      scale: isActive ? [1, 1.3, 1] : 1,
                      opacity: isActive ? 0.9 : 0.5
                    }}
                    transition={{
                      scale: { repeat: Infinity, duration: 2, ease: "easeInOut" },
                      opacity: { duration: 0.3 }
                    }}
                  />
                </g>
              );
            })}

            {/* 最后一个节点 */}
            {buttonPositions.length > 0 && (
              <motion.circle
                cx={buttonPositions[buttonPositions.length - 1].x}
                cy={buttonPositions[buttonPositions.length - 1].y}
                r={activeCategory === categories[categories.length - 1]?.id ? "3" : "2"}
                fill="rgba(139, 92, 246, 0.6)"
                filter="url(#glow)"
                initial={{ scale: 0 }}
                animate={{
                  scale: activeCategory === categories[categories.length - 1]?.id ? [1, 1.3, 1] : 1,
                  opacity: activeCategory === categories[categories.length - 1]?.id ? 0.9 : 0.5
                }}
                transition={{
                  scale: { repeat: Infinity, duration: 2, ease: "easeInOut" },
                  opacity: { duration: 0.3 }
                }}
              />
            )}

            {/* 神经信号脉冲 */}
            {pulseSignals.map(signal => {
              const from = buttonPositions[signal.from];
              const to = buttonPositions[signal.to];
              if (!from || !to) return null;

              const x = from.x + (to.x - from.x) * signal.progress;
              const y = from.y + (to.y - from.y) * signal.progress;

              return (
                <g key={signal.id}>
                  <circle
                    cx={x}
                    cy={y}
                    r="4"
                    fill="rgba(236, 72, 153, 0.9)"
                    filter="url(#glow)"
                  />
                  <circle
                    cx={x}
                    cy={y}
                    r="8"
                    fill="none"
                    stroke="rgba(236, 72, 153, 0.5)"
                    strokeWidth="1"
                    opacity={1 - signal.progress}
                  />
                </g>
              );
            })}
          </svg>
        )}

        {/* 按钮容器 */}
        <div className="flex gap-3 items-end relative z-10">
          {categories.map((category, index) => {
            const scale = calculateScale(index);
            const isActive = activeCategory === category.id;

            return (
              <motion.button
                key={category.id}
                ref={(el) => buttonRefs.current[index] = el}
                onClick={() => onCategoryChange(category.id)}
                onMouseEnter={() => setHoveredIndex(index)}
                onMouseLeave={() => setHoveredIndex(null)}
                className="relative px-6 py-2.5 rounded-full font-medium text-sm group overflow-hidden"
                style={{
                  background: isActive
                    ? 'linear-gradient(135deg, rgba(255,255,255,0.15) 0%, rgba(255,255,255,0.05) 100%)'
                    : 'transparent',
                  backdropFilter: 'blur(10px)',
                  border: isActive ? '1px solid rgba(255,255,255,0.2)' : '1px solid transparent',
                  boxShadow: isActive
                    ? '0 8px 32px rgba(139, 92, 246, 0.15), inset 0 1px 0 rgba(255,255,255,0.1)'
                    : 'none'
                }}
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{
                  opacity: 1,
                  scale: scale,
                  y: mouseX !== null ? -(scale - 1) * 8 : 0
                }}
                transition={{
                  type: "spring",
                  stiffness: 400,
                  damping: 30,
                  mass: 0.5
                }}
                whileHover={{
                  background: 'linear-gradient(135deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.03) 100%)',
                  border: '1px solid rgba(255,255,255,0.15)',
                }}
                whileTap={{ scale: 0.98 }}
              >
                {/* Liquid Glass 高光效果 */}
                <motion.div
                  className="absolute inset-0 rounded-full opacity-0 group-hover:opacity-100"
                  style={{
                    background: 'radial-gradient(circle at 50% 0%, rgba(255,255,255,0.25) 0%, transparent 60%)',
                  }}
                  initial={{ opacity: 0 }}
                  whileHover={{ opacity: 1 }}
                  transition={{ duration: 0.3 }}
                />

                {/* Active 光晕 */}
                {isActive && (
                  <motion.div
                    className="absolute inset-0 rounded-full"
                    style={{
                      background: 'radial-gradient(circle at 50% 50%, rgba(139, 92, 246, 0.1) 0%, transparent 70%)',
                    }}
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{
                      opacity: [0.5, 0.8, 0.5],
                      scale: [0.95, 1, 0.95]
                    }}
                    transition={{
                      duration: 3,
                      repeat: Infinity,
                      ease: "easeInOut"
                    }}
                  />
                )}

                {/* 文字 */}
                <span
                  className="relative z-10 flex items-center gap-2 transition-colors duration-300"
                  style={{
                    color: isActive ? 'rgba(255,255,255,0.95)' : 'rgba(255,255,255,0.6)',
                    textShadow: isActive ? '0 0 20px rgba(139, 92, 246, 0.3)' : 'none'
                  }}
                >
                  {categoryLabels[category.id]}
                </span>
              </motion.button>
            );
          })}
        </div>
      </motion.div>
    </nav>
  );
}
