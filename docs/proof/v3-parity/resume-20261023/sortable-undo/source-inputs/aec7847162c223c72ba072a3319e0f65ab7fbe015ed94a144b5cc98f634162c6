import { isMotionValue } from '../../../value/utils/is-motion-value.mjs';
import { transformPropOrder } from '../../utils/keys-transform.mjs';
import { scrapeMotionValuesFromProps as scrapeMotionValuesFromProps$1 } from '../../html/utils/scrape-motion-values.mjs';

function scrapeMotionValuesFromProps(props, prevProps, visualElement) {
    const newValues = scrapeMotionValuesFromProps$1(props, prevProps, visualElement);
    for (const key in props) {
        /**
         * A MotionValue child is rendered as text content by
         * DOMVisualElement, so it mustn't also be written as an attribute.
         */
        if (key !== "children" &&
            (isMotionValue(props[key]) ||
                isMotionValue(prevProps[key]))) {
            const targetKey = transformPropOrder.indexOf(key) !== -1
                ? "attr" + key.charAt(0).toUpperCase() + key.substring(1)
                : key;
            newValues[targetKey] = props[key];
        }
    }
    return newValues;
}

export { scrapeMotionValuesFromProps };
//# sourceMappingURL=scrape-motion-values.mjs.map
