import { removeItem } from 'motion-utils';
import { releaseElement } from '../animation/animate/element.mjs';
import { resolveElements } from '../utils/resolve-elements.mjs';
import { addToScope, activeScope } from './active.mjs';
import { toMediaQuery } from './media.mjs';

function scopeMotion(...args) {
    const root = typeof args[0] === "function" ? undefined : args.shift();
    const [setup, options = {}] = args;
    const { transition, matchMedia } = options;
    const queries = [];
    const styles = new Map();
    let cleanups = [];
    let isPending = false;
    const active = {
        root: resolveElements(root)[0],
        transition,
        add(cleanup) {
            cleanups.push(cleanup);
            return () => removeItem(cleanups, cleanup);
        },
        bind: (callback) => ((...args) => {
            const result = scope.run(() => callback(...args));
            return typeof result === "function"
                ? active.bind(result)
                : result;
        }),
        track(element) {
            styles.has(element) ||
                styles.set(element, element.getAttribute("style"));
        },
    };
    const clear = (restore) => {
        const current = cleanups;
        cleanups = [];
        for (let i = current.length - 1; i >= 0; i--)
            current[i]();
        restore &&
            styles.forEach((style, element) => {
                releaseElement(element);
                style === null
                    ? element.removeAttribute("style")
                    : element.setAttribute("style", style);
            });
        styles.clear();
    };
    const start = () => {
        scope.state = "active";
        let matches = !queries.length;
        scope.media = {};
        for (const [name, query] of queries) {
            matches = (scope.media[name] = query.matches) || matches;
        }
        if (matches && setup) {
            const cleanup = scope.run(() => setup(scope));
            typeof cleanup === "function" && active.add(cleanup);
        }
    };
    const onChange = () => {
        if (isPending)
            return;
        isPending = true;
        /**
         * Several conditions can change together, for instance two
         * breakpoints crossed by one resize. Refresh once.
         */
        queueMicrotask(() => {
            isPending = false;
            queries.length && scope.refresh();
        });
    };
    const kill = (restore) => {
        scope.state = restore ? "cancelled" : "stopped";
        for (const [, query] of queries) {
            query.removeEventListener("change", onChange);
        }
        queries.length = 0;
        clear(restore);
    };
    const runIn = (target, callback) => {
        const prev = activeScope.current;
        activeScope.current = target;
        try {
            return callback();
        }
        finally {
            activeScope.current = prev;
        }
    };
    const scope = {
        state: "active",
        media: {},
        run: (callback) => runIn(active, callback),
        ignore: (callback) => runIn(undefined, callback),
        bind: active.bind,
        stop: () => kill(),
        cancel: () => kill(true),
        refresh() {
            clear(true);
            start();
        },
    };
    if (matchMedia && typeof window !== "undefined") {
        const conditions = typeof matchMedia === "string"
            ? { matches: matchMedia }
            : matchMedia;
        for (const name in conditions) {
            const query = window.matchMedia(toMediaQuery(conditions[name]));
            query.addEventListener("change", onChange);
            queries.push([name, query]);
        }
    }
    /**
     * A scope created inside another is cancelled with it.
     */
    addToScope(scope.cancel);
    start();
    return scope;
}

export { scopeMotion };
//# sourceMappingURL=index.mjs.map
