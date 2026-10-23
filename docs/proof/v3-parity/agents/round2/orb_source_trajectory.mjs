import { spring } from '/tmp/beui-round2-motion-runtime/node_modules/motion-dom/dist/es/index.mjs';
import { writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('./', import.meta.url));
const physics = { keyframes: [0, 1], stiffness: 700, damping: 50, mass: 0.5, restDelta: 0.001, restSpeed: 0.01 };
const samples = [0, 16, 32, 80, 160, 320, 640].map(timeMs => {
  const value = spring(physics).next(timeMs).value;
  return { timeMs, value, translateYPx: -value * 2, scaleX: 1 + value * 0.04, scaleY: 1 - value * 0.018 };
});
const producer = Array.from({ length: 121 }, (_, i) => {
  const seconds = i / 10;
  const phrase = Math.max(0, Math.sin(seconds * 0.85));
  const syllable = Math.max(0, Math.sin(seconds * 9.3 + Math.sin(seconds * 2.1)));
  return { seconds, activity: phrase * (0.12 + syllable ** 2 * 0.72) };
});
const result = {
  sourceRevision: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', runtime: 'motion-dom 12.43.0 pinned by source bun.lock',
  physics, samples, producer,
  initialState: 'Source target and spring initialize at zero, then the layout effect sets activity. Candidate now passes from: 0 to SingleMotionBuilder.',
  clock: 'Renderer adds min(0.05, frameDeltaSeconds) * speed * (1 + clampedSmoothActivity * 0.6). Candidate uses the same rule.',
  verdict: 'Generator and deterministic silhouette tests only. Not a full trajectory, material, retargeting velocity, or synchronized native-60-FPS pixel proof. Existing 63.6 score and -0.12340906577581237 correlation remain unresolved.',
};
await writeFile(`${root}orb-source-trajectory.json`, JSON.stringify(result, null, 2));
console.log(JSON.stringify(result.samples, null, 2));
