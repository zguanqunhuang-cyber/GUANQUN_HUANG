import { motion } from 'framer-motion';

export default function Header() {
  return (
    <motion.header
      className="fixed top-8 left-8 z-40"
      initial={{ opacity: 0, x: -50 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.8, ease: "easeOut" }}
    >
      <div className="flex items-center gap-3">
        <motion.div
          className="w-10 h-10 rounded-xl bg-white flex items-center justify-center shadow-lg"
          whileHover={{ scale: 1.1, rotate: 360 }}
          transition={{ duration: 0.6 }}
        >
          <img src="/taiji.svg" alt="Taiji" className="w-8 h-8" />
        </motion.div>
        <div>
          <motion.h1
            className="text-2xl font-bold text-white tracking-tight"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.2 }}
          >
            GUANQUN HUANG
          </motion.h1>

        </div>
      </div>
    </motion.header>
  );
}
