import { transformProps } from '../utils/keys-transform.mjs';
import { getDefaultValueType } from '../../value/types/maps/defaults.mjs';
import { createBox } from '../../projection/geometry/models.mjs';
import { DOMVisualElement } from '../dom/DOMVisualElement.mjs';
import { defaultTransformValue } from '../dom/parse-transform.mjs';
import { camelToDash } from '../dom/utils/camel-to-dash.mjs';
import { cssStyleProperties, buildSVGAttrs } from './utils/build-attrs.mjs';
import { camelCaseAttributes } from './utils/camel-case-attrs.mjs';
import { isSVGTag } from './utils/is-svg-tag.mjs';
import { renderSVG } from './utils/render.mjs';
import { scrapeMotionValuesFromProps } from './utils/scrape-motion-values.mjs';

class SVGVisualElement extends DOMVisualElement {
    constructor() {
        super(...arguments);
        this.type = "svg";
        this.isSVGTag = false;
        this.measureInstanceViewportBox = createBox;
    }
    getBaseTargetFromProps(props, key) {
        /**
         * An independent transform's base is never an attribute of the same
         * name, e.g. <rect x> is a position, not a translate. Like HTML it
         * comes from style, falling back to the transform's default.
         */
        return transformProps.has(key)
            ? super.getBaseTargetFromProps(props, key) ??
                defaultTransformValue(key)
            : props[key];
    }
    /**
     * An independent transform's origin is never read from the DOM, so it
     * starts from its latest or default value and renders on mount.
     */
    getDefaultValue(key) {
        return transformProps.has(key)
            ? this.latestValues[key] ?? defaultTransformValue(key)
            : undefined;
    }
    readValueFromInstance(instance, key) {
        if (transformProps.has(key)) {
            const defaultType = getDefaultValueType(key);
            return defaultType ? defaultType.default || 0 : 0;
        }
        if (cssStyleProperties.includes(key)) {
            const computedStyle = getComputedStyle(instance);
            const value = computedStyle[key];
            if (typeof value === "string" && value)
                return value.trim();
        }
        key = !camelCaseAttributes.has(key) ? camelToDash(key) : key;
        return instance.getAttribute(key);
    }
    scrapeMotionValuesFromProps(props, prevProps, visualElement) {
        return scrapeMotionValuesFromProps(props, prevProps, visualElement);
    }
    build(renderState, latestValues, props) {
        buildSVGAttrs(renderState, latestValues, this.isSVGTag, props.transformTemplate, props.style);
    }
    renderInstance(instance, renderState, styleProp, projection) {
        renderSVG(instance, renderState, styleProp, projection);
    }
    mount(instance) {
        this.isSVGTag = isSVGTag(instance.tagName);
        super.mount(instance);
    }
}

export { SVGVisualElement };
//# sourceMappingURL=SVGVisualElement.mjs.map
