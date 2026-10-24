import { activeScope, addBuilderToScope } from '../scope/active.mjs';
import { parseAnimateLayoutArgs, LayoutAnimationBuilder } from './LayoutAnimationBuilder.mjs';

/**
 * Animate layout changes made within `updateDom` on elements tagged
 * with `data-layout` or `data-layout-id`.
 *
 * ```
 * animateLayout(() => {
 *     element.style.justifyContent = "flex-end"
 * })
 * ```
 */
function animateLayout(scopeOrUpdateDom, updateDomOrOptions, options) {
    const { scope, updateDom, defaultOptions } = parseAnimateLayoutArgs(scopeOrUpdateDom, updateDomOrOptions, options);
    const builder = new LayoutAnimationBuilder(scope, updateDom, {
        ...activeScope.current?.transition,
        ...defaultOptions,
    });
    addBuilderToScope(builder);
    return builder;
}

export { animateLayout };
//# sourceMappingURL=animate-layout.mjs.map
