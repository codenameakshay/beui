# Shared animated sidebar contract

Design only. Production implementation remains baseline-gated. Source is pinned
to `1ab921e6`; the existing Flutter API is the `792ad82d` baseline.

## Decision

Use candidate B's single private owner model with A's declarative caller shape.
Both complete sketches were independently produced by Luna. A fresh Luna judge
scored B higher for lifecycle and compatibility. Owner review confirmed that
the existing `_expanded` getter projects `true` for `collapsible.none` and that
the existing public scope publishes that effective value. Preserve it.

```text
BeuiAnimatedSidebarProvider owns private state model
  BeuiAnimatedSidebarScope exposes values and requests
    ChatApp / Trigger / AnimatedSidebar read the same owner
      panel projects collapsible.none without rewriting owner state
```

`Separate Before Serializing Shared State` shaped this choice. There will be
one expansion/mobile state machine, not an agents-side copy or callback bridge.
`Exhaust the Design Space` required the distinct provider-state and model-owner
sketches before this selection. `Prove It Works` keeps the design verdict
separate from unrun ownership, input, lifecycle and visual tests.

## Caller usage and types

```dart
BeuiAnimatedSidebarProvider(
  expanded: desktopOpen,
  onExpandedChange: requestDesktopOpen,
  openMobile: mobileOpen,
  onOpenMobileChange: requestMobileOpen,
  child: BeuiAnimatedSidebar(
    groups: groups,
    child: workspaceWithTrigger,
  ),
)

// Existing standalone usage stays unchanged.
BeuiAnimatedSidebar(
  groups: groups,
  defaultExpanded: false,
  child: workspaceWithTrigger,
)
```

New public provider constructor:

```dart
BeuiAnimatedSidebarProvider({
  required Widget child,
  bool? expanded,
  bool defaultExpanded = true,
  ValueChanged<bool>? onExpandedChange,
  bool? openMobile,
  bool defaultOpenMobile = false,
  ValueChanged<bool>? onOpenMobileChange,
  double mobileBreakpoint = kBeuiAnimatedSidebarMobileBreakpoint,
  bool enableKeyboardShortcut = true,
  Key? key,
})
```

Preserve every existing sidebar constructor parameter, the public Scope
constructor, and `of`/`maybeOf`. Add only an optional
`bool isExpandedControlled = false` Scope field so source-style shell fitting
can avoid issuing owner requests when controlled. No public controller,
attachment protocol, notifier or disposal obligation is exposed.

## Ownership and release behavior

The nearest new provider is authoritative for expanded/mobile values,
callbacks, breakpoint and shortcut policy. A sidebar under it borrows the
private owner. It never creates, synchronizes or disposes another model.
Legacy sidebar controlled arguments and callbacks under a provider are a
configuration conflict. Debug assertions identify them; release builds use
provider values and callbacks only. Legacy defaults are ignored under a
provider. This precedence is not assertion-dependent.

Without a provider, the legacy sidebar creates the same private owner type,
configured from its existing arguments. Its callback and default behavior
stays intact. Selection, submenu expansion, resource-tree state and measured
active rects remain local view/domain state, not provider state.

The private owner stores raw desktop intent independently from mobile-open.
The provider scope exposes that intent. Within a legacy `collapsible.none`
panel, the existing Scope lookup still exposes effective `expanded=true`.
Requests route to the same raw owner. A no-collapse panel never writes true
back into it. Changing collapse mode reveals the retained raw intent.

Controlled values do not mutate on requests; each request notifies the owning
callback once. Uncontrolled defaults seed once and do not reset on rebuild.
Viewport crossing changes `isMobile`, not either stored boolean, and emits
no open-change callback. Width767 is mobile; width768 is desktop.

One owner installs one shortcut handler. A borrowed sidebar installs none.
Nearest focused provider handles Cmd/Ctrl+B once; nested outer owners do not
also toggle. Trigger focus nodes stay widget-owned. The private owner can
remember the invoker without owning/disposal of external focus nodes. Sheet
focus trap and restore stay with the rendered sheet, with an attached trigger
fallback if the invoker disappears.

## Agents shell-fit integration

Source `chat-app.tsx:43-67,81-95` is not merely a static breakpoint layout.
Its measured shell width changes desktop-open only on width crossings when
uncontrolled. First wide measurement leaves the caller's default alone;
first narrow measurement folds immediately. A manual toggle persists until
the next crossing. Already-satisfied state emits no redundant callback.

The source-compatible ChatApp composition must use this same owner and check
`scope.isExpandedControlled` before fitting. Fit calls `scope.setExpanded`,
never `setOpenMobile`. Its600px measured-shell policy is independent of the
provider's768px viewport mode. The agents owner retains the legacy ChatApp
slot constructor and its sidebarOpen/onSidebarDismiss behavior on that path;
the additive source composition path must not create an unrelated sidebar
state machine. Exact ChatApp constructor naming belongs to agents.

## Verification before acceptance

Test standalone legacy calls, provider-only calls, borrowed and nested panels,
controlled transitions and control handoff, ignored defaults on rebuild,
callback counts, none-to-icon mode changes,767/768 viewport crossings,
first-wide/first-narrow shell measurement and subsequent crossings, manual
toggle persistence, nearest-only shortcuts from editable controls, invoker
removal, mobile exit gating and disposal. Existing constructors and manual
Scope construction must still compile. No runtime result is claimed yet.

Rejected A's raw-state-only scope projection because it changes legacy none
behavior. Rejected exporting B's controller because it adds a second public
state path and lifecycle burden. Retained B's private carrier/model and A's
simple declarative usage. The source/default state API remains additive.
