import { isPrimaryPointer } from '../gestures/utils/is-primary-pointer.mjs';

function extractEventInfo(event) {
    return {
        point: {
            x: event.pageX,
            y: event.pageY,
        },
    };
}
const addPointerInfo = (handler) => (event) => isPrimaryPointer(event) && handler(event, extractEventInfo(event));

export { addPointerInfo, extractEventInfo };
//# sourceMappingURL=event-info.mjs.map
