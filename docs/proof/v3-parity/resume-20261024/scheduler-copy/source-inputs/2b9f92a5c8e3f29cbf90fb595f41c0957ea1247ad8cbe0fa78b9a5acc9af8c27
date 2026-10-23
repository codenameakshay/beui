import { acquireProjectionNode } from '../../layout/LayoutAnimationBuilder.mjs';
import { activeScope, addToScope } from '../../scope/active.mjs';
import { resolveElements } from '../../utils/resolve-elements.mjs';
import { VisualElementDragControls } from './VisualElementDragControls.mjs';

const toProps = ({ axis, constraints, elastic, momentum, transition, snapToOrigin, directionLock, propagation, onStart, onMove, onEnd, onDirectionLock, onTransitionEnd, onMeasureConstraints, }) => ({
    drag: axis || true,
    dragConstraints: constraints,
    dragElastic: elastic,
    dragMomentum: momentum,
    dragTransition: transition,
    dragSnapToOrigin: snapToOrigin,
    dragDirectionLock: directionLock,
    dragPropagation: propagation,
    onDragStart: onStart,
    onDrag: onMove,
    onDragEnd: onEnd,
    onDirectionLock,
    onDragTransitionEnd: onTransitionEnd,
    onMeasureDragConstraints: onMeasureConstraints,
});
const dragStyles = [
    "user-select",
    "-webkit-user-select",
    "-webkit-touch-callout",
    "touch-action",
];
/**
 * Apply the styles React's drag prop applies, so touch input drags
 * instead of panning the page, and text selection and native drag (ghost
 * image) don't interrupt the gesture. Returns a function that restores
 * the element's previous values.
 */
function applyDragStyles(element, axis) {
    const { style } = element;
    const draggable = element.getAttribute("draggable");
    const prev = dragStyles.map((key) => style.getPropertyValue(key));
    const touchAction = axis ? "pan-" + (axis === "x" ? "y" : "x") : "none";
    dragStyles.forEach((key, i) => style.setProperty(key, i < 3 ? "none" : touchAction));
    element.setAttribute("draggable", "false");
    return () => {
        dragStyles.forEach((key, i) => style.setProperty(key, prev[i]));
        draggable === null
            ? element.removeAttribute("draggable")
            : element.setAttribute("draggable", draggable);
    };
}
/**
 * Make elements draggable. Returns a function that removes the gesture.
 *
 * ```javascript
 * const stop = drag("#box", { axis: "x", constraints: { left: 0, right: 300 } })
 * ```
 *
 * The element's `x` and `y` are motion values shared with `animate()`
 * and `animateLayout()`, so these can animate the element after a drag.
 *
 * @public
 */
function drag(elementOrSelector, options = {}) {
    const props = toProps(options);
    const scope = activeScope.current;
    /**
     * Run callbacks in the active scope, so work they start is collected.
     */
    if (scope) {
        for (const key in props) {
            const value = props[key];
            if (typeof value === "function") {
                props[key] = scope.bind(value);
            }
        }
    }
    const cleanups = resolveElements(elementOrSelector).map((element) => {
        scope?.track(element);
        const [node, release] = acquireProjectionNode(element);
        /**
         * Measure layout even when not animating it, as constraints and
         * layout-shift correction are computed from it.
         */
        node.setOptions({ alwaysMeasureLayout: true });
        const controls = new VisualElementDragControls(node.options.visualElement, () => props);
        const removeListeners = controls.addListeners();
        const removeStyles = applyDragStyles(element, options.axis);
        return () => {
            removeStyles();
            removeListeners?.();
            controls.cancel();
            controls.stopAnimation();
            release();
        };
    });
    return addToScope(() => cleanups.forEach((cleanup) => cleanup()));
}

export { drag };
//# sourceMappingURL=index.mjs.map
