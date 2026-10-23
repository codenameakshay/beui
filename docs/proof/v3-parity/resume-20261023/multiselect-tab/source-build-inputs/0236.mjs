import { addToScope } from '../scope/active.mjs';
import { resizeElement } from './handle-element.mjs';
import { resizeWindow } from './handle-window.mjs';

function resize(a, b) {
    return addToScope(typeof a === "function" ? resizeWindow(a) : resizeElement(a, b));
}

export { resize };
//# sourceMappingURL=index.mjs.map
