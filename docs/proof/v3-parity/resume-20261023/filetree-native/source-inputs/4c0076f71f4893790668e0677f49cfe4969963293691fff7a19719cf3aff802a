const activeScope = {};
/**
 * Register `cleanup` with the active scope, if there is one, so stopping
 * the scope also runs it.
 */
function addToScope(cleanup) {
    activeScope.current?.add(cleanup);
    return cleanup;
}
/**
 * Collect the animation a builder like `animateLayout()` or
 * `animateView()` resolves with. If the scope stops first, the animation
 * is stopped as soon as it starts.
 */
function addBuilderToScope(builder) {
    const scope = activeScope.current;
    if (!scope)
        return;
    let isStopped = false;
    let stop;
    const remove = scope.add(() => {
        isStopped = true;
        stop?.();
    });
    builder.then((animation) => {
        if (!animation)
            return;
        stop = () => animation.stop();
        isStopped ? stop() : animation.finished.then(remove);
    }, remove);
}
/**
 * Bind `callback` to the active scope, so anything it starts later (for
 * instance an animation in an `inView()` callback) is collected too.
 */
const bindToScope = (callback) => activeScope.current ? activeScope.current.bind(callback) : callback;

export { activeScope, addBuilderToScope, addToScope, bindToScope };
//# sourceMappingURL=active.mjs.map
