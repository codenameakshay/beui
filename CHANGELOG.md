## 2.0.0

Codebase slop audit. No component was redesigned; this release removes
duplication, dead code, and process residue that accumulated across the
1.x agent passes, and fixes the bugs found on the way. It is a major
because the dead and deprecated API below is deleted rather than kept.

### Removed (breaking)

* `beuiSidebarCanContain` (use `BeuiSidebarResource.canContain`) and
  `citationTargetId`.
* `BeuiGlass.strongBg`, `thinBg`, `strongBlur`, `thinBlur` — no component
  rendered them; `bg`, `border` and `blur` remain.
* `BeuiAgentLayout.density` and `BeuiAgentDensity` — no component branched
  on them; `BeuiAgentTheme.compact` still tightens the spacing tokens.
* The 1.x compatibility slots `BeuiCodeBlock.filenameNode`,
  `BeuiFileDiff.fileNode` and `BeuiPreviewRailStyle.trackExtent`; use
  `filename`/`filenameWidget`, `file`/`fileWidget` and `itemSize`.
* The widget-test key constants for the animated, AI and bounce sidebars
  are no longer exported from the barrel; they are `@visibleForTesting`
  internals.

### Fixed

* A fresh `pub get` no longer fails to compile: `flutter_lucide` renamed
  `trash_2` to `trash` in 1.41 and `rotate_ccw_clock` only exists from
  1.31, so the lower bound is now `>=1.41.0` and the glyph is renamed.
* `BeuiAgentTheme.decorateCard` passed the glass palette's 20px CSS radius
  straight in as a Gaussian sigma, rendering at twice the source blur.
* A `MaterialApp` without the `BeuiColors` extension no longer throws in
  36 components, and two components no longer fall back to the light
  palette in dark mode: every lookup goes through `BeuiColors.resolve`.
* `BeuiRangeSlider` adopts the shared slider state, so a range whose max
  is not a step multiple can reach it, fractional steps stop leaking
  float dust, and its semantics gain increase/decrease actions.
* `BeuiAttachmentUpload`: cancelling or removing a row mid-transfer no
  longer flips it to "Upload complete" when the simulated timer fires.
* `BeuiContextMenu` no longer throws from `num.clamp` on viewports
  narrower than the panel; its remeasure loop is capped.
* `BeuiPopover`'s hover-close delay is cancelled on re-hover and dispose.
* `BeuiPreviewRail`'s two-tap touch preview no longer resets itself on an
  unrelated rebuild.
* `BeuiPromptInput` re-measures when `maxRows` changes.
* `BeuiShaderBackground` discards a program that finished loading after
  the variant changed, and disposes superseded shaders and the noise codec.
* `BeuiAnimatedSidebar` honours a custom `width` in the offcanvas box;
  two `AnimatedOpacity` wrappers that could never animate are gone.
* `BeuiExpandingArrowButton` no longer allocates a `CurvedAnimation` per
  frame per chevron or wraps its reveal in a dead `TweenAnimationBuilder`.
* Availability scheduler's time select no longer leaks a
  `ScrollController` per overlay rebuild.
* Cascade text (`BeuiTextCascade`, stateful button, action swap, loading
  states) animates grapheme clusters instead of UTF-16 code units.
* Six hand-rolled focus borders use `BeuiFocusRing`, so focusing no
  longer shifts layout and the ring meets 3:1 contrast.

### Added

* `BeuiColors.resolve(context)`; `beuiSpringSnap` and `beuiSpringScroll`
  motion tokens.
* `BeuiAiSidebar.onRenameError`, `BeuiFeedbackWidget.onSubmitError`
  (errors were previously swallowed); `BeuiMultiChainSwap.networkFee`,
  `slippage`, `eta` (previously hardcoded literals).
* `BeuiAgentIcons.externalLink` now reaches the citation and attachment
  link glyphs.
* Widget tests for `BeuiMagnetic` and `BeuiParallax`.

### Internal

* Shared helpers replace per-file copies: cascade text, disclosure
  chevron, ring spinner, streaming status icon, glyph scramble, shake
  interpolator, thousands grouping and address truncation; `lerpDouble`,
  `listEquals`, `num.clamp`, `Curves.*` and `math.pi` replace hand-rolled
  equivalents; every blur routes through `beuiBlurSigma`.
* Dead parameters, fields, branches and the test-only probe shader are
  gone; comments no longer cite internal audit ticket ids.
* `test/support.dart` owns the themed test app, blur probe, frame pump
  and contrast math; ~110 tautological or build-only tests are deleted
  and the shader tests now assert the shader's own paint.
* The gallery's 14-in-one `core_demos.dart` is split per catalog slug
  (which fixes the Code tab's source paths), with one shared replay
  button, section label and pressable control.
* `.pubignore` excludes the example's platform folders and fonts.

## 1.2.0

UX-audit remediation across the chat/agent family — 154 audited findings
resolved (docs/UX_AUDIT_AGENT_CHAT_FLOWS.md holds the audit). Almost all API
is additive; the deliberate default changes are listed under "Changed
defaults" below.

### Trust & failure states

* `BeuiToolApproval`: details open by default whenever parameters exist; a
  `severity` tier (`normal`/`elevated`/`destructive`) that re-weights the
  actions for irreversible commands (warning glyph, tinted border, Deny
  promoted, Always-allow suppressed); `expired`/`timedOut` statuses; `grant`
  records once-vs-always and an `onRevoke` affordance for standing grants;
  the action row can no longer double-fire during its exit.
* `BeuiStreamingResponse`: `error` is now visibly failed (destructive notice
  + retry) instead of pixel-identical to `complete`; new `stopped` status with
  a Continue affordance.
* `BeuiAgentActivity`: `failed`/`cancelled` statuses — a crashed run no longer
  summarizes as success.
* `BeuiImageGeneration`: determinate `progress` hairline and `onCancel`.

### Keyboard & screen readers

* Full keyboard contracts (focus, Enter/Space, Esc, visible focus ring) for:
  tool-approval actions, the composer's `+` menu and model picker,
  `BeuiFileUpload` (dropzone/remove/retry), the feedback widget's trigger and
  close, and sidebar rows (visible focus + selected ≠ hover).
* Esc now dismisses `BeuiOverlay` surfaces even with `trapFocus: false`.
* The transcript announces streamed text through one debounced live region
  (sentence-boundary announcements; `announceText`/`onAnnounce` hooks) instead
  of 3–5 nested regions announcing nothing; terminal outcomes (Failed, Denied,
  Copied, Sent) are announced.
* Focus rings paint outside layout via the new `focusRing` color role
  (≥3:1 in all 22 theme×brightness combos) — focusing no longer shifts
  content.
* 44px minimum hit areas across the family; upload progress announced with
  units and completion.

### Contrast

* Placeholders, tool slugs, metadata, line-number gutters, citation domains,
  and light-mode status badges move from 1.6–3.7:1 to AA-passing values;
  `outline` bubbles get a visible edge; `danger` bubbles gain a leading glyph
  and AA text.

### Composer & uploads

* `BeuiPromptInput`: attachment chip rail (`attachments`, `onAttachmentRemoved`,
  `onAttachmentRetry`, `onSubmitFull` with `BeuiPromptSubmission`), one
  keyboard-driven model picker (`BeuiSelectOption.icon`), viewport-aware menu
  placement, Enter-while-streaming feedback (`onSubmitBlocked`), memoised
  measurement for large pastes.
* Upload components: real `progress` on attachment items, cancel-in-flight
  (`onCancel`) distinct from remove, `maxFileSize` + inline rejection notice,
  seekable audio scrubber (`onSeek`), honest default dropzone copy.
* `BeuiInput`: left-aligned error text (was centered — golden-verified),
  announced errors, label association, shake replay via `errorNonce`, and the
  standard `TextField` pass-throughs (autofill, input action, formatters,
  maxLength, readOnly…).
* `BeuiFeedbackWidget`: drafts survive dismissal, submit validates inline
  instead of disabling, optional sentiment row (`showSentiment`), announced
  and screen-reader-stable success state.

### Reading long/streamed content

* Jump-to-latest pills with unread counts on the message scroller; streaming
  code/diff/tool-result viewports stop yanking the reader to the live edge
  once they scroll away, and capped viewports show a fade + "N more lines".
* `BeuiFileDiff`: wide lines are horizontally scrollable or wrapped
  (`wrap: adaptive` by default) instead of ellipsised; header copy control;
  hunk-gap markers with optional context expansion (`onExpandContext`) and
  change navigation; unified-diff `copyText` default.
* `BeuiMessageScroller.builder` — lazy sliver path for long transcripts.
* `BeuiPreviewRail` works on touch (tap-to-preview, tap-again-to-commit) and
  marks the active destination by default.
* `BeuiChatApp`: responsive `sidebarBreakpoint`, keyboard-inset avoidance,
  bubble width clamped (no more debug assert below 44px).

### Changed defaults (deliberate, audit-driven)

* `BeuiMessage`/`BeuiMessageBubble` `animateIn` now default to true
  (mount-only; streaming updates never replay).
* `BeuiToolApproval.defaultOpen` resolves by `parameters.isNotEmpty`.
* `BeuiPreviewRail.highlightActive` defaults to true.
* `BeuiFileUpload` copy: "Browse files" / drag wording is opt-in
  (`dragAndDrop`) because OS drop needs a consumer plugin.
* `BeuiToolApproval`/`BeuiToolResult` `tool`/`title`/`description`/`meta`
  narrowed from `Object` to typed `String?` + `Widget?` pairs
  (`filename`/`file` likewise on code block and diff, with deprecated
  `*Node` params still accepted).

### Localization

* `BeuiAgentStrings` now covers the full agent family (approval, results,
  activity, todos, streaming actions, jump-to-latest); resolution is
  widget param → theme strings → defaults.

### Theming roles

* New `BeuiColors.focusRing` role — clears WCAG 2.2 SC 1.4.11 (3:1) on all
  11 themes in both brightnesses; `ring` is unchanged and stays for hairline
  borders. Amber and lime cannot clear 3:1 in light mode at any alpha, so
  their focus hue is darkened to 60% oklch lightness.
* New `BeuiAgentTheme.statusLight`/`statusDark` (`BeuiAgentStatusColors`,
  `BeuiAgentStatusPalette`) — agent status color was previously ~50 hardcoded
  literals and could not be rethemed; painted defaults are preserved except
  the AA lift noted under Contrast.

### Fixes

* The package did not compile: `LucideIcons.history` was removed in
  flutter_lucide 1.31.0. Replaced with `rotate_ccw_clock`.
* `BeuiPullToRefresh`: the indicator did not track the finger during the pull
  (frozen at rest until release) — for all users, not only reduced motion.
* Reduced-motion "arrival" fixes: the agent-activity feed, collapsible
  bubbles, todo progress arcs and strikethroughs, disclosure chevrons, and
  the command-palette/context-menu selection highlight now reach their target
  state under `disableAnimations` instead of freezing mid-transition.

### Internal

* One shared syntax highlighter replaces three diverged copies (JSON keys now
  highlight as properties, bash tokenizes positionally, diffs handle `@@`);
  one shared disclosure primitive replaces eight, with a reduced-motion branch
  that keeps an opacity fade instead of hard-cutting.

## 1.1.0

Semantic theming for the AI-agent family, plus compact-to-expanded approval
cards. Default visuals and motion are unchanged: omit `BeuiAgentTheme` and
every agent widget still resolves to the 1.0.0 source-fidelity look.

### Agent theming

* New `BeuiAgentTheme` `ThemeExtension` — typography roles, bubble/card
  radii, conversation spacing, density, borders, optional glass cards, and
  semantic icon slots. Install it next to `BeuiColors`; `ThemeData.fontFamily`
  still owns the typeface.
* AI-agent widgets read those tokens instead of hard-coded source sizes,
  padding, and Lucide defaults. Constructor overrides remain.
* Gallery route **Agent Theme** shows a custom warm-green palette, inherited
  font, radii, density, icons, and an expandable approval card using the real
  widgets.

### Approval card

* Additive compact-to-expanded API: `expanded` / `defaultExpanded` /
  `onExpandedChanged`, `compactChild` / `expandedChild`, `headerAction`.
  Existing call sites are unchanged. Height uses `beuiSpringLayout` and is
  interruptible; reduced motion snaps.

### Compatibility

* Minor release. No required migrations. `BeuiChatApp.borderRadius` and
  `BeuiMessageBubbleContent.maxWidthFactor` are now nullable so the theme can
  supply the default; omitted arguments still resolve to 16 and 0.82.

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
