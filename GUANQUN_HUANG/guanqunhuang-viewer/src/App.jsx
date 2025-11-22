import { useState } from 'react';
import Header from './components/Header';
import CategoryNav from './components/CategoryNav';
import BenchmarkGrid from './components/BenchmarkGrid';
import ArtBackground from './components/ArtBackground';
import { benchmarkData } from './data/benchmarkData';

function App() {
  const [activeCategory, setActiveCategory] = useState(benchmarkData.categories[0].id);

  const currentCategory = benchmarkData.categories.find(
    cat => cat.id === activeCategory
  );

  return (
    <div className="min-h-screen relative">
      {/* 世界名画背景 */}
      <ArtBackground />

      {/* Main content */}
      <div className="relative z-10 pt-24 pb-32">
        <Header />
        <CategoryNav
          categories={benchmarkData.categories}
          activeCategory={activeCategory}
          onCategoryChange={setActiveCategory}
        />
        <BenchmarkGrid category={currentCategory} />
      </div>

    </div>
  );
}

export default App;
