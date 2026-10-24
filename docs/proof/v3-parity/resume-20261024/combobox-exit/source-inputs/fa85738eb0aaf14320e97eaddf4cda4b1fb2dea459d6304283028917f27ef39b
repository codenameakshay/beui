"use client";
import { buildSVGAttrs, isSVGTag } from 'motion-dom';
import { useMemo } from 'react';
import { copyRawValuesOnly } from '../html/use-props.mjs';
import { createSvgRenderState } from './utils/create-render-state.mjs';

function useSVGProps(props, visualState, _isStatic, Component) {
    const visualProps = useMemo(() => {
        const state = createSvgRenderState();
        buildSVGAttrs(state, visualState, isSVGTag(Component), props.transformTemplate, props.style);
        return {
            ...state.attrs,
            style: { ...state.style },
        };
    }, [visualState]);
    if (props.style) {
        /**
         * Build a fresh style each render rather than writing back into
         * the memoised visualProps, which would carry the previous
         * render's raw styles over (and above) the latest ones.
         */
        const style = {};
        copyRawValuesOnly(style, props.style, props);
        return { ...visualProps, style: { ...style, ...visualProps.style } };
    }
    return visualProps;
}

export { useSVGProps };
//# sourceMappingURL=use-props.mjs.map
