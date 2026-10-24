import { createProjectionNode } from './create-projection-node.mjs';
import { DocumentProjectionNode } from './DocumentProjectionNode.mjs';
import { rootProjectionNode } from './root.mjs';

const HTMLProjectionNode = 
/* @__PURE__ */ createProjectionNode({
    measureScroll: (instance) => ({
        x: instance.scrollLeft,
        y: instance.scrollTop,
    }),
    defaultParent: () => {
        if (!rootProjectionNode.current) {
            const documentNode = new DocumentProjectionNode({});
            documentNode.mount(window);
            documentNode.setOptions({ layoutScroll: true });
            rootProjectionNode.current = documentNode;
        }
        return rootProjectionNode.current;
    },
    resetTransform: (instance, value) => {
        instance.style.transform = value !== undefined ? value : "none";
    },
    checkIsScrollRoot: (instance) => Boolean(window.getComputedStyle(instance).position === "fixed"),
});

export { HTMLProjectionNode };
//# sourceMappingURL=HTMLProjectionNode.mjs.map
