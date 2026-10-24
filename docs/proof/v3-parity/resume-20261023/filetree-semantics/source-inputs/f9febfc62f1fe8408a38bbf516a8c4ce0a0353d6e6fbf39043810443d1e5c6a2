import { resolveVariantFromProps } from './resolve-variants.mjs';

function resolveVariant(visualElement, definition, custom) {
    return resolveVariantFromProps(visualElement.getProps(), definition, custom, visualElement);
}
/**
 * Exit variants resolve with AnimatePresence's custom, every other type
 * with the element's own.
 */
const getTypeCustom = (visualElement, type) => type === "exit" ? visualElement.presenceContext?.custom : undefined;

export { getTypeCustom, resolveVariant };
//# sourceMappingURL=resolve-dynamic-variants.mjs.map
