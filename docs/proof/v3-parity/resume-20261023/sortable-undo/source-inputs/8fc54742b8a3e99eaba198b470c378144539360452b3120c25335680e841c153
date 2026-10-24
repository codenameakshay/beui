"use client";
import { jsx } from 'react/jsx-runtime';
import { isMotionValue, visualElementStore } from 'motion-dom';
import { invariant } from 'motion-utils';
import { forwardRef, useContext, useState } from 'react';
import { ReorderContext } from '../../context/ReorderContext.mjs';
import { motion } from '../../render/components/motion/proxy.mjs';
import { useConstant } from '../../utils/use-constant.mjs';
import { useMotionValue } from '../../value/use-motion-value.mjs';
import { useTransform } from '../../value/use-transform.mjs';
import { autoScrollIfNeeded, resetAutoScrollState } from './utils/auto-scroll.mjs';

function useDefaultMotionValue(value, defaultValue = 0) {
    return isMotionValue(value) ? value : useMotionValue(defaultValue);
}
function ReorderItemComponent({ children, style = {}, value, as = "li", onDrag, onDragEnd, onKeyDown, onBlur, layout = true, ...props }, externalRef) {
    const Component = useConstant(() => motion[as]);
    const context = useContext(ReorderContext);
    /**
     * The group's values when this item was grabbed with the keyboard, for
     * Escape to restore. Set only while grabbed.
     */
    const [grabbedFrom, setGrabbedFrom] = useState();
    const point = {
        x: useDefaultMotionValue(style.x),
        y: useDefaultMotionValue(style.y),
    };
    const zIndex = useTransform([point.x, point.y], ([latestX, latestY]) => latestX || latestY ? 1 : "unset");
    invariant(Boolean(context), "Reorder.Item must be a child of Reorder.Group", "reorder-item-child");
    const { axis, registerItem, updateOrder, groupRef, hasReordered, onKeyDown: handleKeyDown, } = context;
    const dragAxis = axis === "xy" ? true : axis;
    /**
     * A keyboard grab is a drag without a pointer, so it shares whileDrag
     * (but not the drag callbacks, which need a pointer and PanInfo).
     */
    const grab = (element, from) => {
        setGrabbedFrom(from);
        visualElementStore
            .get(element)
            ?.animationState?.setActive("whileDrag", !!from);
    };
    return (jsx(Component, { drag: dragAxis, tabIndex: 0, ...props, dragSnapToOrigin: true, style: { ...style, x: point.x, y: point.y, zIndex }, layout: layout, onDrag: (event, gesturePoint) => {
            const { velocity, point: pointerPoint } = gesturePoint;
            const offset = { x: point.x.get(), y: point.y.get() };
            updateOrder(value, offset, velocity);
            const scrollAxis = axis === "xy"
                ? Math.abs(velocity.x) > Math.abs(velocity.y)
                    ? "x"
                    : "y"
                : axis;
            autoScrollIfNeeded(groupRef.current, pointerPoint[scrollAxis], scrollAxis, velocity[scrollAxis]);
            onDrag && onDrag(event, gesturePoint);
        }, onDragEnd: (event, gesturePoint) => {
            // Runs a frame after release, so after the release's click
            hasReordered.current = false;
            resetAutoScrollState();
            onDragEnd && onDragEnd(event, gesturePoint);
        }, onKeyDown: (event) => {
            onKeyDown?.(event);
            handleKeyDown(event, value, grabbedFrom, grab);
        }, 
        /**
         * A move blurs the item, but that blur is never dispatched:
         * React DOM disables its events while it commits, and restores
         * focus to the item before re-enabling them. So any blur that
         * reaches here is focus really leaving, which drops the item.
         */
        onBlur: (event) => {
            onBlur?.(event);
            grabbedFrom && grab(event.currentTarget);
        }, onLayoutMeasure: (measured) => {
            registerItem(value, measured);
        }, ref: externalRef, ignoreStrict: true, children: children }));
}
const ReorderItem = /*@__PURE__*/ forwardRef(ReorderItemComponent);

export { ReorderItem, ReorderItemComponent };
//# sourceMappingURL=Item.mjs.map
