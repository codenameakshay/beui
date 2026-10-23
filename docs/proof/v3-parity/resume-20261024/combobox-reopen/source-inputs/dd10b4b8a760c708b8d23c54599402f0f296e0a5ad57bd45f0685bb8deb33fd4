import { time } from '../frameloop/sync-time.mjs';
import { secondsToMilliseconds } from 'motion-utils';
import { bindToScope, addToScope } from '../scope/active.mjs';
import { frame, cancelFrame } from '../frameloop/frame.mjs';

/**
 * Timeout defined in ms
 */
function delay(callback, timeout) {
    const start = time.now();
    callback = bindToScope(callback);
    const checkElapsed = ({ timestamp }) => {
        const elapsed = timestamp - start;
        if (elapsed >= timeout) {
            cancelFrame(checkElapsed);
            callback(elapsed - timeout);
        }
    };
    frame.setup(checkElapsed, true);
    return addToScope(() => cancelFrame(checkElapsed));
}
function delayInSeconds(callback, timeout) {
    return delay(callback, secondsToMilliseconds(timeout));
}

export { delay, delayInSeconds };
//# sourceMappingURL=delay.mjs.map
