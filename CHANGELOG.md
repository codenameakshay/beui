## 1.0.0

Initial release — a one-to-one Flutter port of beUI v2, built on the
[`motor`](https://pub.dev/packages/motor) motion engine so the source's exact
spring physics carry over. All 72 beui.dev catalog entries across three groups.

A beui.dev page is not always one component: several pages ship multiple
independently-installable widgets, and all of them are covered here.

### Components (motion primitives)

Tilt Card, Button (+ Stateful + Magnetic), Animated CTA Buttons (expanding /
hold / slide), Marquee, Tabs, Switch, Input, Select (+ Morph), Checkbox,
Radio Group, Bottom Sheet, Pull to Refresh, Shared Layout Background,
Bounce Sidebar, Animated Sidebar (sidebar / floating / inset), Preview Rail,
Dock (+ separator-grouped actions), Tooltip, Context Menu, Popover (+ Morph),
Morphing Modal, Center Morph Modal, Text Animation (reveal / shimmer /
cascade / chromatic), Number Animation (count-up + ticker), Animated Badge,
Action Swap (blur / roll / cascade), Animated Toast Stack, Theme Toggle
(rectangle / circle / circle-blur / blinds), Bouncy Accordion, Drawer,
Scroll Animation (smooth scroll / progress / reveal / scroll-to / parallax),
Range Slider (ticked / fluid / wave / bubble / ruler), Wheel Picker, Table,
Shader Background (21 GPU variants), Cylinder Carousel, Loader (17 variants).

### Blocks (composed patterns)

Infinite Masonry, Notification Stack, Fixtures (knockout bracket with
third-place playoff + knockout wheel), Availability Scheduler,
Multi-chain Swap, Dynamic Island, Command Palette, Expandable Action Bar,
Overflow Actions, Expandable Tabs, Swipeable List, File Upload (upload queue
+ attachment workspace), Prediction Market, Wallet Card, OTP Input,
Bloom Menu, Feedback Widget, 404 / Not Found (5 variants).

### AI Agents (conversational interfaces)

Message Bubble, Message, Message Scroller, Prompt Input, Todo List,
Code Block, Approval Card, File Diff, Tool Result, Streaming Response,
Image Generation, Tool Approval, Citations, Agent Activity, Agent Loading
States (thinking shimmer / agent progress / reasoning text), AI Sidebar,
Chat App.

### Foundation

* Spring and easing motion tokens mirroring the source `ease.ts`, resolved
  through a single `motor`-backed facade.
* `BeuiColors` `ThemeExtension` with light/dark and 11 color themes.
* Shared `BeuiOverlay` foundation for every floating surface (tooltip, drawer,
  sheet, modal, command palette).
* Reduced-motion resolver (`motionFor`) that drops movement while preserving
  opacity/color feedback.
* Default `flutter_lucide` icon set re-exported through the barrel.

### Deliberate departures from the source

* No dual-thumb range slider — beui.dev ships five single-value sliders and no
  range variant.
* File pickers are the consumer's: `BeuiFileUpload` and `BeuiAttachmentUpload`
  carry file metadata and expose `onBrowse`, so the package takes no
  file-picker dependency.
* Compound React components (`Tabs`/`TabsList`/`TabsTrigger`, `Select`/
  `SelectTrigger`/…, the `AnimatedSidebar*` family) collapse into single
  widgets taking item models, per the Flutter conventions in
  `docs/PORTING_SPEC.md` §6.
