import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const artworks = [
  {
    id: 'starry-night',
    name: '星空 - 梵高',
    url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg/1280px-Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg',
    artist: 'Vincent van Gogh'
  },
  {
    id: 'great-wave',
    name: '神奈川冲浪里 - 葛饰北斋',
    url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/The_Great_Wave_off_Kanagawa.jpg/1280px-The_Great_Wave_off_Kanagawa.jpg',
    artist: 'Katsushika Hokusai'
  },
  {
    id: 'creation-adam',
    name: '创造亚当 - 米开朗基罗',
    url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5b/Michelangelo_-_Creation_of_Adam_%28cropped%29.jpg/1280px-Michelangelo_-_Creation_of_Adam_%28cropped%29.jpg',
    artist: 'Michelangelo'
  },
  {
    id: 'scream',
    name: '呐喊 - 蒙克',
    url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Edvard_Munch%2C_1893%2C_The_Scream%2C_oil%2C_tempera_and_pastel_on_cardboard%2C_91_x_73_cm%2C_National_Gallery_of_Norway.jpg/800px-Edvard_Munch%2C_1893%2C_The_Scream%2C_oil%2C_tempera_and_pastel_on_cardboard%2C_91_x_73_cm%2C_National_Gallery_of_Norway.jpg',
    artist: 'Edvard Munch'
  },
  {
    id: 'girl-pearl',
    name: '戴珍珠耳环的少女 - 维米尔',
    url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/1665_Girl_with_a_Pearl_Earring.jpg/800px-1665_Girl_with_a_Pearl_Earring.jpg',
    artist: 'Johannes Vermeer'
  }
];

export default function ArtBackground() {
  const [currentArt, setCurrentArt] = useState(0);
  const [isChanging, setIsChanging] = useState(false);

  // 自动切换画作（每30秒）
  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentArt((prev) => (prev + 1) % artworks.length);
    }, 30000);
    return () => clearInterval(interval);
  }, []);

  const handleNext = () => {
    if (!isChanging) {
      setIsChanging(true);
      setCurrentArt((prev) => (prev + 1) % artworks.length);
      setTimeout(() => setIsChanging(false), 1000);
    }
  };

  const handlePrev = () => {
    if (!isChanging) {
      setIsChanging(true);
      setCurrentArt((prev) => (prev - 1 + artworks.length) % artworks.length);
      setTimeout(() => setIsChanging(false), 1000);
    }
  };

  return (
    <div className="fixed inset-0 w-full h-full overflow-hidden" style={{ zIndex: 0 }}>
      {/* 背景图片容器 */}
      <AnimatePresence mode="wait">
        <motion.div
          key={currentArt}
          className="absolute inset-0 w-full h-full"
          initial={{ opacity: 0, scale: 1.1 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.9 }}
          transition={{ duration: 1.5, ease: "easeInOut" }}
        >
          {/* 画作背景 */}
          <div
            className="w-full h-full bg-cover bg-center"
            style={{
              backgroundImage: `url(${artworks[currentArt].url})`,
              filter: 'brightness(0.4) contrast(1.1)',
            }}
          />

          {/* 渐变遮罩 - 让文字更清晰 */}
          <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-black/40 to-black/70" />
        </motion.div>
      </AnimatePresence>

      {/* 画作信息标签 */}
      <motion.div
        className="absolute bottom-8 left-8 glass-effect px-6 py-3 rounded-full"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.5 }}
      >
        <p className="text-sm text-gray-300">
          🎨 {artworks[currentArt].name}
        </p>
      </motion.div>

      {/* 画作指示器 */}
      <div className="absolute bottom-24 right-8 flex flex-col gap-2">
        {artworks.map((_, index) => (
          <button
            key={index}
            onClick={() => {
              if (!isChanging) {
                setIsChanging(true);
                setCurrentArt(index);
                setTimeout(() => setIsChanging(false), 1000);
              }
            }}
            className={`w-2 h-2 rounded-full transition-all ${
              index === currentArt
                ? 'bg-white w-2 h-8'
                : 'bg-white/30 hover:bg-white/60'
            }`}
          />
        ))}
      </div>
    </div>
  );
}
