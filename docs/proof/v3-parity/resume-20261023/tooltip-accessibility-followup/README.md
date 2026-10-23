# Accessibility activation after mouse exit

Independent review demonstrated that Tooltip retained mouse modality after the pointer left and was removed. A later semantic tap invoked the child's action but failed to open the tooltip. The original review file and result are preserved byte-for-byte as text. The runnable repository copy changes the support import and formatting only; its assertions remain unchanged.

Production 2b1a8ae52 clears pointer kind when the trigger receives pointer exit. Mouse reentry still establishes mouse modality, so clicks continue to dismiss rather than toggle. The original reviewer test runs unchanged from its /tmp fixture and passes all five cases after the repair. The repository reproduction had four passes and one failure before, then passed in the 323-test Tooltip/overlay/chart batch. Controlled and disabled cases retain the child's action and controlled ownership. Scoped analysis and release build pass.

Fresh native verification passes all four mouse/touch contexts under normal and reduced motion. It also checks repeated mouse click, native Tab and Escape, and touch open/close/open/close. Actual served script hashes and both effective Flutter motion flags are retained. The accessibility transition itself is proven by the semantic-action widget reproduction, not a physical screen-reader session.

The initial analyzer reported a braces lint in the portable review test. Adding braces changed no assertion; the corrected analyzer log is retained. Earlier full-root results remain tied to f59e909b2; this follow-up uses focused verification. Bump focus loss and exact parity remain open.
