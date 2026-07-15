"use client"

import { motion } from "framer-motion"
import { useEffect, useState } from "react"

type Particle = {
  id: number
  left: number
  size: number
  duration: number
  delay: number
  drift: number
}

export function Embers({ count = 24 }: { count?: number }) {
  const [particles, setParticles] = useState<Particle[]>([])

  // Generate random particles only on the client to avoid SSR hydration mismatch.
  useEffect(() => {
    setParticles(
      Array.from({ length: count }).map((_, i) => ({
        id: i,
        left: Math.random() * 100,
        size: 2 + Math.random() * 4,
        duration: 6 + Math.random() * 10,
        delay: Math.random() * 8,
        drift: (Math.random() - 0.5) * 80,
      })),
    )
  }, [count])

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      {particles.map((p) => (
        <motion.span
          key={p.id}
          className="absolute rounded-full"
          style={{
            left: `${p.left}%`,
            bottom: -10,
            width: p.size,
            height: p.size,
            background: "radial-gradient(circle, rgba(255,170,0,0.9), rgba(255,80,0,0.2))",
            boxShadow: "0 0 8px rgba(255,140,0,0.7)",
          }}
          initial={{ y: 0, opacity: 0 }}
          animate={{
            y: [0, -420 - Math.random() * 200],
            x: [0, p.drift],
            opacity: [0, 0.9, 0.7, 0],
          }}
          transition={{
            duration: p.duration,
            delay: p.delay,
            repeat: Number.POSITIVE_INFINITY,
            ease: "easeOut",
          }}
        />
      ))}
    </div>
  )
}
