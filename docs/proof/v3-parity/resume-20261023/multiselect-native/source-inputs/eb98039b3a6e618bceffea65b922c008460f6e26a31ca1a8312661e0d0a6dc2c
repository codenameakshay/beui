import { motionValue } from './index.mjs';
import { keyframes } from '../animation/generators/keyframes.mjs';
import { replaceTransitionType } from '../animation/utils/replace-transition-type.mjs';
import { follow } from './utils/follow.mjs';
import { isMotionValue } from './utils/is-motion-value.mjs';

/**
 * Create a `MotionValue` that animates to its latest value using any transition type.
 * Can either be a value or track another `MotionValue`.
 *
 * ```jsx
 * const x = motionValue(0)
 * const y = followValue(x, { type: "spring", stiffness: 300 })
 * // or with tween
 * const z = followValue(x, { type: "tween", duration: 0.5, ease: "easeOut" })
 * ```
 *
 * @param source - Initial value or MotionValue to track
 * @param options - Animation transition options
 * @returns `MotionValue`
 *
 * @public
 */
function followValue(source, options) {
    const initialValue = isMotionValue(source) ? source.get() : source;
    const value = motionValue(initialValue);
    attachFollow(value, source, options);
    return value;
}
/**
 * Attach an animation to a MotionValue that will animate whenever the value changes.
 * Similar to attachSpring but supports any transition type (spring, tween, inertia, etc.)
 *
 * @param value - The MotionValue to animate
 * @param source - Initial value or MotionValue to track
 * @param options - Animation transition options
 * @returns Cleanup function
 *
 * @public
 */
function attachFollow(value, source, options = {}) {
    // Default to spring if no type specified (matches useSpring behavior)
    const transition = { type: "spring", ...options };
    replaceTransitionType(transition);
    transition.type = transition.type || keyframes;
    return follow(value, source, transition);
}

export { attachFollow, followValue };
//# sourceMappingURL=follow-value.mjs.map
