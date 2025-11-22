import { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import CLOUDS2 from 'vanta/dist/vanta.clouds2.min';

export default function VantaBackground() {
  const vantaRef = useRef(null);
  const [vantaEffect, setVantaEffect] = useState(null);

  useEffect(() => {
    if (!vantaEffect) {
      setVantaEffect(
        CLOUDS2({
          el: vantaRef.current,
          THREE: THREE,
          mouseControls: true,
          touchControls: true,
          gyroControls: false,
          minHeight: 200.00,
          minWidth: 200.00,
          // 官网配色 - 梦幻蓝色天空
          backgroundColor: 0x0,           // 黑色背景
          skyColor: 0x446699,             // 蓝色天空
          cloudColor: 0x66aabb,           // 浅蓝云彩
          cloudShadowColor: 0x183550,     // 云影
          sunColor: 0xffffff,             // 白色阳光
          sunGlareColor: 0xffffff,        // 白色光晕
          sunlightColor: 0xffffff,        // 白色阳光
          speed: 1,                        // 正常速度
          scale: 1.00,
          scaleMobile: 1.00
        })
      );
    }
    return () => {
      if (vantaEffect) vantaEffect.destroy();
    };
  }, [vantaEffect]);

  return (
    <div
      ref={vantaRef}
      className="fixed inset-0 w-full h-full"
      style={{ zIndex: 0 }}
    />
  );
}
