## 0.0.1

Initial release — a one-to-one Flutter port of beUI v2, built on the
[`motor`](https://pub.dev/packages/motor) motion engine so the source's exact
spring physics carry over. 49 components across two groups.

### Components (motion primitives)

Marquee, Tabs, Switch, Input, Select (+ Morph), Checkbox, Radio Group,
Bottom Sheet, Shared Layout Background, Preview Rail, Dock, Tooltip,
Popover (+ Morph), Morphing Modal, Text Animation (reveal / shimmer / cascade),
Number Animation, Animated Badge, Action Swap, Animated Toast Stack,
Theme Toggle, Bouncy Accordion, Drawer, Scroll Animation, Range Slider,
Wheel Picker, Table, Shader Background (21 GPU variants), Cylinder Carousel,
Loader, Tilt Card, Button (+ Stateful + Magnetic).

### Blocks (composed patterns)

Availability Scheduler, Multi-chain Swap, Dynamic Island, Command Palette,
Expandable Action Bar, Overflow Actions, Expandable Tabs, Swipeable List,
File Upload, Prediction Market, Wallet Card, OTP Input, Bloom Menu,
Feedback Widget, 404 / Not Found (5 variants), Infinite Masonry,
Notification Stack, Knockout Bracket.

### Foundation

* Spring and easing motion tokens mirroring the source `ease.ts`, resolved
  through a single `motor`-backed facade.
* `BeuiColors` `ThemeExtension` with light/dark and 11 color themes.
* Shared `BeuiOverlay` foundation for every floating surface (tooltip, drawer,
  sheet, modal, command palette).
* Reduced-motion resolver (`motionFor`) that drops movement while preserving
  opacity/color feedback.
* Default `flutter_lucide` icon set re-exported through the barrel.

Not yet ported: Pull to Refresh, Animated CTA Buttons.
