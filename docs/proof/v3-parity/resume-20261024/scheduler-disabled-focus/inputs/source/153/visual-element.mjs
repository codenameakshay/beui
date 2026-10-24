import { resolveVariant } from '../../render/utils/resolve-dynamic-variants.mjs';
import { animateTarget } from './visual-element-target.mjs';
import { animateVariant } from './visual-element-variant.mjs';

function animateVisualElement(visualElement, definition, options = {}) {
    visualElement.notify("AnimationStart", definition);
    const animation = Array.isArray(definition)
        ? Promise.all(definition.map((variant) => animateVariant(visualElement, variant, options)))
        : typeof definition === "string"
            ? animateVariant(visualElement, definition, options)
            : Promise.all(animateTarget(visualElement, resolveVariant(visualElement, definition, options.custom), options));
    return animation.then(() => {
        visualElement.notify("AnimationComplete", definition);
    });
}

export { animateVisualElement };
//# sourceMappingURL=visual-element.mjs.map
