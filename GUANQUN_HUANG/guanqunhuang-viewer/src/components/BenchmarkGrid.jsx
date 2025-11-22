import { motion, AnimatePresence } from 'framer-motion';
import BenchmarkCard from './BenchmarkCard';

export default function BenchmarkGrid({ category }) {
  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      {/* Cards grid */}
      <AnimatePresence mode="wait">
        <motion.div
          key={category.id}
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 items-start"
          initial={{ opacity: 1 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
        >
          {category.items.map((item, index) => (
            <BenchmarkCard
              key={item.id}
              item={item}
              gradient={category.gradient}
              index={index}
            />
          ))}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
