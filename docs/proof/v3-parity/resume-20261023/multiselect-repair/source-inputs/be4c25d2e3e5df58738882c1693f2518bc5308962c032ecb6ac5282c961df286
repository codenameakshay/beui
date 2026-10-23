function getValueState(visualElement) {
    const state = [{}, {}];
    visualElement?.values.forEach((value, key) => {
        state[0][key] = value.get();
        state[1][key] = value.getVelocity();
    });
    return state;
}
function resolveVariantFromProps(props, definition, custom, visualElement) {
    const resolveFunction = (def) => typeof def === "function"
        ? def(custom !== undefined ? custom : props.custom, ...getValueState(visualElement))
        : def;
    /**
     * Resolve a function, then a variant label (which the function may have
     * returned), then a function again as the label may point to one. The
     * final function can only return a target object.
     */
    definition = resolveFunction(definition);
    if (typeof definition === "string") {
        definition = props.variants && props.variants[definition];
    }
    return resolveFunction(definition);
}

export { resolveVariantFromProps };
//# sourceMappingURL=resolve-variants.mjs.map
