"use client";
import { scopeMotion } from 'motion-dom';
import { useRef } from 'react';
import { useIsomorphicLayoutEffect } from '../../utils/use-isomorphic-effect.mjs';

/**
 * Run `setup` in a `scopeMotion()` scope rooted at `ref`, so selectors
 * resolve inside it. The scope is cancelled on unmount, or when `deps`
 * change, which stops everything started in it and restores inline styles.
 *
 * ```jsx
 * const ref = useRef(null)
 * useScopeMotion(ref, () => {
 *     inView("li", (el) => animate(el, { opacity: 1 }))
 * })
 * return <ul ref={ref}>...</ul>
 * ```
 *
 * Returns a ref to the current scope, for `run()` and `bind()` in event
 * handlers.
 *
 * @public
 */
function useScopeMotion(ref, setup, { deps = [], ...options } = {}) {
    const scope = useRef(null);
    const latestSetup = useRef(setup);
    latestSetup.current = setup;
    useIsomorphicLayoutEffect(() => {
        const current = (scope.current = scopeMotion(ref?.current || undefined, (s) => latestSetup.current(s), options));
        return () => {
            current.cancel();
            if (scope.current === current)
                scope.current = null;
        };
    }, deps);
    return scope;
}

export { useScopeMotion };
//# sourceMappingURL=use-scope-motion.mjs.map
