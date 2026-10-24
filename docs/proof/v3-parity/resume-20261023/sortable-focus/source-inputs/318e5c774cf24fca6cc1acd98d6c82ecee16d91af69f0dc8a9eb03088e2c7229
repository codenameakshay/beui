import { bindToScope, addToScope } from 'motion-dom';
import { noop } from 'motion-utils';
import { attachToAnimation } from './attach-animation.mjs';
import { scrollInfo } from './track.mjs';

function scroll(onScroll, { axis = "y", source, container = document.scrollingElement, ...options } = {}) {
    if (!container)
        return noop;
    const optionsWithDefaults = {
        axis,
        container: source || container,
        ...options,
    };
    if (typeof onScroll === "function") {
        const callback = bindToScope(onScroll);
        return addToScope(scrollInfo((info) => callback(info[axis].progress, info), optionsWithDefaults));
    }
    return addToScope(attachToAnimation(onScroll, optionsWithDefaults));
}

export { scroll };
//# sourceMappingURL=index.mjs.map
