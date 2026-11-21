'use client';

import { Children, type ReactNode } from 'react';
import { motion, useReducedMotion } from 'motion/react';

export function MotionPage({ children, className = '' }: { children: ReactNode; className?: string }) {
  const reducedMotion = useReducedMotion();
  return (
    <motion.div
      className={className}
      initial={reducedMotion ? false : { opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.42, ease: [0.2, 0.8, 0.2, 1] }}
    >
      {children}
    </motion.div>
  );
}

export function MotionGrid({ children, className = '' }: { children: ReactNode; className?: string }) {
  const reducedMotion = useReducedMotion();
  const items = Children.toArray(children);
  return (
    <motion.div
      className={className}
      initial="hidden"
      animate="visible"
      variants={{
        hidden: {},
        visible: { transition: { staggerChildren: reducedMotion ? 0 : 0.055 } },
      }}
    >
      {items.map((item, index) => (
        <motion.div
          key={index}
          variants={{
            hidden: reducedMotion ? { opacity: 1 } : { opacity: 0, y: 14 },
            visible: { opacity: 1, y: 0 },
          }}
          transition={{ duration: reducedMotion ? 0 : 0.38, ease: [0.2, 0.8, 0.2, 1] }}
        >
          {item}
        </motion.div>
      ))}
    </motion.div>
  );
}

