import { resolveOffset } from '../offsets/offset.mjs';
import { ScrollOffset } from '../offsets/presets.mjs';

/**
 * Resolved offsets are linear in the target and container lengths, so
 * probing them gives [target progress, container progress, pixels].
 * vw/vh can resolve to 0px, so they're rejected up front.
 */
const toIntersection = (o) => {
    if (/v/u.test(o))
        return [];
    const px = resolveOffset(o, 0, 0, 0);
    return [resolveOffset(o, 0, 1, 0) - px, px - resolveOffset(o, 1, 0, 0), px];
};
const toRange = ([t, c, px]) => !px &&
    (c === 0 || c === 1) &&
    `${c ? "entry" : "exit"}-crossing ${t * 100}%`;
/**
 * Maps an offset to an equivalent ViewTimeline range. Returns undefined when
 * there isn't one, which signals the caller to fall back to JS-based scroll
 * tracking.
 */
function offsetToViewTimelineRange(offset = ScrollOffset.All) {
    if (offset.length !== 2)
        return;
    const [start, end] = offset.map(toIntersection);
    const points = [toRange(start), toRange(end)];
    const a = end[0] - start[0];
    const b = start[1] - end[1];
    if (points[0] && points[1] && (a || b)) {
        return {
            points: points,
            a,
            b,
            cover: !start[0] && a === 1 && b === 1,
        };
    }
}

export { offsetToViewTimelineRange };
//# sourceMappingURL=offset-to-range.mjs.map
