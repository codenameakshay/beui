# Supplemental source geometry

These live measurements follow the original recordings. They do not retroactively establish matching capture geometry. The viewport is 1440 by 1000 at DPR 1 with dark theme. The source checkout revision is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The live deployment revision is unknown.

Every measured source preview stage is 752px wide at this viewport. The immediate child widths vary by route. Separate values below follow the source examples' DOM order. The raw bounds, classes, timestamps, and nested children are in [source-geometry.json](source-geometry.json).

| Route | Immediate visible child bounds in px |
|---|---|
| prompt-input | 576 by 360 |
| message | 576 by 440 |
| message-bubble | 576 by 440; 576 by 410; 576 by 410 |
| message-scroller | 576 by 440 |
| streaming-response | 576 by 500 |
| image-generation | 576 by 314 |
| citations | 512 by 410 |
| loading-states | 384 by 201.5; 82.703125 by 28; 189.0625 by 24 |
| todo-list | 512 by 330 |
| agent-activity | Four examples at 512 by 330; one at 576 by 330; one at 576 by 300 |
| tool-result | Two examples at 512 by 330 |
| code-block | 576 by 340 |
| file-diff | 512 by 300 |
| tool-approval | 512 by 360 |
| approval-card | 512 by 470; 512 by 360 |
| ai-sidebar | 752 by 744, including 12px padding on each side |
| chat-app | 752 by 784, including 12px padding on each side |
| voice-orb | 288 by 288 |

The candidate recordings use the unchanged `visual_harness.dart` entrypoint and its 48px outer padding, not the explorer shell. That entrypoint ignores `previewWidth`. No baseline wrapper or shared-width commit was applied. No matched-stage-width verdict is claimed.

Child bounds include preview wrappers and are not necessarily the innermost widget size. AI Sidebar and Chat App each have an inner width of 728px. The missing second Chat App stage target remains null in the raw JSON and does not count as measured evidence. The loading text widths describe the observed phrase at measurement time, not a fixed API constraint.
