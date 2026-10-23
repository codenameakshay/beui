import { styleSubjectEffect } from '../../effects/style/index.mjs';
import { svgSubjectEffect } from '../../effects/svg/index.mjs';
import { measureViewportBox } from '../../projection/utils/measure.mjs';
import { isSVGElement } from '../../utils/is-svg-element.mjs';
import { activeScope } from '../../scope/active.mjs';
import { transformGroups } from '../waapi/transforms/groups.mjs';
import { DOMKeyframesResolver } from '../keyframes/DOMKeyframesResolver.mjs';
import { animateValues, animateEffectSubject } from './effects.mjs';

const noProps = {};
const getElementEffect = (element) => (isSVGElement(element)
    ? svgSubjectEffect
    : styleSubjectEffect);
/**
 * Presents an effect bound to a DOM element in the shape the DOM keyframe
 * resolver and WAAPI expect, which is that of a VisualElement. Holds no
 * state: everything delegates to the effect. Goes once the resolver takes
 * an effect and subject directly.
 */
class EffectSubject {
    constructor(effect, current) {
        this.effect = effect;
        this.current = current;
        this.KeyframeResolver = DOMKeyframesResolver;
    }
    getValue(key) {
        return this.effect.get(this.current, key);
    }
    readValue(key, target) {
        return this.effect.read(this.current, key, target);
    }
    render() {
        this.effect.flush(this.current);
    }
    measureViewportBox() {
        return measureViewportBox(this.current);
    }
    getProps() {
        return noProps;
    }
}
/**
 * Animate a DOM element's styles. HTML elements are bound through
 * styleEffect, SVG through svgEffect, and both are resolved with the DOM
 * keyframe resolver so reads are batched, units are converted by
 * measurement and eligible values run on WAAPI.
 *
 * Pass the element's VisualElement (a <motion.*> component or an
 * animateLayout() node) to animate its values instead, so the two keep
 * sharing values and a renderer.
 */
function animateElement(element, keyframes, transition, visualElement) {
    activeScope.current?.track(element);
    if (visualElement) {
        return animateValues((key) => visualElement.getValue(key, null), keyframes, transition, visualElement);
    }
    const effect = getElementEffect(element);
    return animateEffectSubject(effect, element, keyframes, transition, new EffectSubject(effect, element));
}
/**
 * Detach the values styleEffect/svgEffect bound to `element`, so the
 * next animation reads its starting values from the DOM again.
 */
const releaseElement = (element) => getElementEffect(element)
    .state(element)
    ?.release();
/**
 * Hand the values styleEffect/svgEffect are rendering on `element`,
 * whether bound by animate() or directly, to a VisualElement that now
 * owns the element (e.g. created by animateLayout()), so a single
 * renderer drives them alongside its own values.
 */
function handOffElementState(element, visualElement) {
    const state = getElementEffect(element).state(element);
    if (!state)
        return;
    /**
     * A transform group reads values through the effect state, which is
     * about to be emptied. Hand its animations to the main thread (writing
     * their current transform) and detach it, so animations the
     * VisualElement starts form a new group that reads from it.
     */
    const group = transformGroups.get(element);
    if (group) {
        group.demote();
        transformGroups.delete(element);
    }
    const { transformKeys } = state;
    state.release().forEach((value, key) => {
        /**
         * The style effect derives transform (from the bound transform
         * keys) and transformBox itself; a VisualElement builds its own.
         */
        const derived = key === "transformBox" ||
            (key === "transform" && transformKeys?.length);
        if (!derived) {
            value.owner = visualElement;
            visualElement.addValue(key, value);
        }
    });
}

export { animateElement, handOffElementState, releaseElement };
//# sourceMappingURL=element.mjs.map
