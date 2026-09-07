import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// ---------------------------------------------------------------------------
// Tokens (source `animated-sidebar.tsx`)
// ---------------------------------------------------------------------------

/// Desktop expanded width — source `--sidebar-width: 16rem`.
const double kBeuiAnimatedSidebarWidth = 256;

/// Icon-rail width when collapsed — source `--sidebar-width-icon: 4.25rem`.
const double kBeuiAnimatedSidebarIconWidth = 68;

/// Mobile sheet width — source `--sidebar-width-mobile: 18rem`.
const double kBeuiAnimatedSidebarMobileWidth = 288;

/// Mobile breakpoint — source `MOBILE_QUERY = (max-width: 767px)`.
const double kBeuiAnimatedSidebarMobileBreakpoint = 768;

/// Critically damped width morph so the rail cannot overshoot a hard zero
/// boundary (source `SIDEBAR_MORPH_TRANSITION`: 380 / 35 / 0.75).
const _morphSpring = SpringMotion(
  SpringDescription(mass: 0.75, stiffness: 380, damping: 35),
);

/// Panel / mobile sheet slide (source `PANEL_TRANSITION`: 0.36s `EASE_DRAWER`).
const _panelSlide = CurvedMotion(Duration(milliseconds: 360), beuiEaseDrawer);

/// Reduced-motion fallback (source `REDUCED_TRANSITION`: 0.16s `EASE_OUT`).
const _reducedMotion = CurvedMotion(Duration(milliseconds: 160), beuiEaseOut);

/// Label enter (source `LABEL_ENTER_TRANSITION`: 0.2s delay 0.08s).
const _labelEnter = Duration(milliseconds: 200);
const _labelEnterDelay = Duration(milliseconds: 80);

/// Label exit (source `LABEL_EXIT_TRANSITION`: 0.12s).
const _labelExit = Duration(milliseconds: 120);

/// Keyboard shortcut key (source `SIDEBAR_KEYBOARD_SHORTCUT = "b"` with ⌘/Ctrl).
const _shortcutKey = LogicalKeyboardKey.keyB;

/// Detached-surface inset for the `floating` / `inset` variants — source `m-2`
/// (0.5rem), which is also what makes their height `calc(100svh - 1rem)`.
const double _detachedMargin = 8;

/// Corner radius of a detached panel — source `rounded-2xl` (Tailwind v4: 1rem).
const double _detachedRadius = 16;

/// Source `shadow-sm` (Tailwind v4): `0 1px 3px 0 rgb(0 0 0 / .1)`,
/// `0 1px 2px -1px rgb(0 0 0 / .1)`. Carried by the `floating` panel and by the
/// `inset` variant's content surface.
const List<BoxShadow> _detachedShadow = [
  BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1)),
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 2,
    spreadRadius: -1,
    offset: Offset(0, 1),
  ),
];

// ---------------------------------------------------------------------------
// Test handles
// ---------------------------------------------------------------------------

/// Test handle on the desktop sidebar panel.
@visibleForTesting
const beuiAnimatedSidebarPanelKey = ValueKey<String>(
  'beui_animated_sidebar_panel',
);

/// Test handle on the mobile sheet panel.
@visibleForTesting
const beuiAnimatedSidebarMobilePanelKey = ValueKey<String>(
  'beui_animated_sidebar_mobile_panel',
);

/// Test handle on the active-item shared-layout indicator.
@visibleForTesting
const beuiAnimatedSidebarActiveKey = ValueKey<String>(
  'beui_animated_sidebar_active',
);

/// Test handle on the desktop panel's chrome — the surface carrying the
/// variant's background, border, corner radius and shadow.
@visibleForTesting
const beuiAnimatedSidebarChromeKey = ValueKey<String>(
  'beui_animated_sidebar_chrome',
);

/// Test handle on the `inset` variant's detached content surface (source
/// `AnimatedSidebarInset`'s `md:peer-data-[variant=inset]` chrome). Absent for
/// the `sidebar` and `floating` variants, and on mobile.
@visibleForTesting
const beuiAnimatedSidebarInsetKey = ValueKey<String>(
  'beui_animated_sidebar_inset',
);

// ---------------------------------------------------------------------------
// Public enums & models
// ---------------------------------------------------------------------------

/// Which edge the sidebar anchors to (source `SidebarSide`).
enum BeuiAnimatedSidebarSide {
  /// Left edge (default).
  left,

  /// Right edge.
  right,
}

/// Panel chrome on desktop (source `SidebarVariant`). Ignored on mobile, where
/// the sheet always renders as a flush, bordered, shadowed drawer — exactly as
/// the source, whose `AnimatedSidebar` short-circuits to `MobileSidebar` before
/// the variant is read.
enum BeuiAnimatedSidebarVariant {
  /// Flush panel with a border on its inner edge — a left sidebar borders
  /// right, a right sidebar borders left. Source `"sidebar"` (the default).
  sidebar,

  /// A detached card: inset by 8 on every side (source `m-2` +
  /// `h-[calc(100svh-1rem)]`), 16 corner radius (`rounded-2xl`), bordered all
  /// round and lifted with a `shadow-sm`. Source `"floating"`.
  floating,

  /// Same detached geometry as [floating] but with **no** border or shadow —
  /// and the main content ([BeuiAnimatedSidebar.child]) becomes the detached
  /// surface instead, gaining the margin, radius and shadow (source
  /// `AnimatedSidebarInset`'s `md:peer-data-[variant=inset]` rules).
  /// Source `"inset"`.
  inset,
}

/// Collapse behaviour when desktop [BeuiAnimatedSidebar.expanded] is false
/// (source `SidebarCollapsible`).
enum BeuiAnimatedSidebarCollapsible {
  /// Fold to an icon rail (default). Source `"icon"`.
  icon,

  /// Slide fully off-canvas (width → 0). Source `"offcanvas"`.
  offcanvas,

  /// Never collapse; ignore expanded state. Source `"none"`.
  none,
}

/// One nav destination — leaf or parent with nested [children].
///
/// Maps the source compound tree (`AnimatedSidebarMenuItem` +
/// `AnimatedSidebarMenuButton` + optional `AnimatedSidebarMenuSub`) into a
/// single data model that Flutter can own without a compound-component graph.
@immutable
class BeuiAnimatedSidebarItem {
  /// Creates a sidebar destination.
  const BeuiAnimatedSidebarItem({
    required this.id,
    required this.label,
    this.icon,
    this.badge,
    this.children,
    this.disabled = false,
  });

  /// Stable identity used for [BeuiAnimatedSidebar.selectedId] / onSelected.
  final String id;

  /// Visible row label (also used as tooltip when the rail is collapsed).
  final String label;

  /// Optional leading glyph. Framework-native [IconData] (defaults rendered
  /// via [LucideIcons] only as demo content — never required).
  final IconData? icon;

  /// Optional trailing badge (e.g. inbox count `"4"`). Hidden when collapsed.
  final String? badge;

  /// Nested destinations. When non-empty, tapping toggles the submenu (and
  /// does **not** select this parent unless it has no selectable leaf).
  final List<BeuiAnimatedSidebarItem>? children;

  /// When true the row is dimmed and non-interactive.
  final bool disabled;

  /// Whether this item has nested children.
  bool get hasChildren => children != null && children!.isNotEmpty;
}

/// A labeled section of [items] (source `AnimatedSidebarGroup` +
/// `AnimatedSidebarGroupLabel` + `AnimatedSidebarGroupContent`).
@immutable
class BeuiAnimatedSidebarGroup {
  /// Creates a group. [label] may be null for an unlabeled top section.
  const BeuiAnimatedSidebarGroup({this.label, required this.items});

  /// Optional uppercase section header; fades out when the rail collapses.
  final String? label;

  /// Rows inside this group.
  final List<BeuiAnimatedSidebarItem> items;
}

// ---------------------------------------------------------------------------
// Scope (source `AnimatedSidebarProvider` / `useAnimatedSidebar`)
// ---------------------------------------------------------------------------

/// Ambient expand / mobile-open state for [BeuiAnimatedSidebarTrigger] and
/// nested chrome. Analog of the source `AnimatedSidebarProvider` context.
class BeuiAnimatedSidebarScope extends InheritedWidget {
  /// Creates a scope.
  const BeuiAnimatedSidebarScope({
    required this.expanded,
    required this.openMobile,
    required this.isMobile,
    required this.toggle,
    required this.setExpanded,
    required this.setOpenMobile,
    required super.child,
    super.key,
  });

  /// Desktop expanded (labels visible). Always true when collapsible is none.
  final bool expanded;

  /// Whether the mobile sheet is open.
  final bool openMobile;

  /// Whether the layout is currently below the mobile breakpoint.
  final bool isMobile;

  /// Toggle desktop expand (or mobile sheet, when [isMobile]).
  final VoidCallback toggle;

  /// Set desktop expanded state.
  final ValueChanged<bool> setExpanded;

  /// Set mobile sheet open state.
  final ValueChanged<bool> setOpenMobile;

  /// Nearest scope, or null outside a [BeuiAnimatedSidebar].
  static BeuiAnimatedSidebarScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BeuiAnimatedSidebarScope>();
  }

  /// Nearest scope; throws if missing.
  static BeuiAnimatedSidebarScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'BeuiAnimatedSidebarScope.of() called outside BeuiAnimatedSidebar.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(BeuiAnimatedSidebarScope old) {
    return expanded != old.expanded ||
        openMobile != old.openMobile ||
        isMobile != old.isMobile;
  }
}

// ---------------------------------------------------------------------------
// Trigger (source `AnimatedSidebarTrigger`)
// ---------------------------------------------------------------------------

/// Icon button that toggles the nearest [BeuiAnimatedSidebar] (desktop expand
/// or mobile sheet). Place it in the inset header.
class BeuiAnimatedSidebarTrigger extends StatelessWidget {
  /// Creates a trigger. Defaults to a [LucideIcons.panel_left] glyph.
  const BeuiAnimatedSidebarTrigger({
    this.icon,
    this.tooltip = 'Toggle sidebar',
    super.key,
  });

  /// Glyph override. Defaults to [LucideIcons.panel_left].
  final IconData? icon;

  /// Tooltip / semantics label.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scope = BeuiAnimatedSidebarScope.maybeOf(context);
    final colors = BeuiColors.resolve(context);
    final open = scope == null
        ? true
        : (scope.isMobile ? scope.openMobile : scope.expanded);

    return Tooltip(
      message: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: scope?.toggle,
        icon: Icon(
          icon ?? LucideIcons.panel_left,
          size: 16,
          color: colors.mutedForeground,
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          maximumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        isSelected: open,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

/// A composable application sidebar with morphing nested navigation that folds
/// into an animated icon rail on desktop and becomes a focus-managed sheet on
/// mobile — the Flutter port of beUI's `animated-sidebar`.
///
/// ## Source mapping
///
/// The React source is a large compound-component kit
/// (`AnimatedSidebarProvider` + `AnimatedSidebar` + Header/Content/Footer/
/// Menu/MenuButton/MenuSub/…). Flutter ports the **behaviour** into a
/// data-driven widget:
///
/// | Source | Flutter |
/// | --- | --- |
/// | `AnimatedSidebarProvider` open/openMobile | [expanded] / [openMobile] (both controlled + uncontrolled) |
/// | `AnimatedSidebar` collapsible/side/variant | [collapsible] / [side] / [variant] |
/// | `AnimatedSidebarInset` inset chrome | [child], wrapped when [variant] is inset |
/// | Menu groups + items | [groups] of [BeuiAnimatedSidebarItem] |
/// | Nested `MenuSub` | [BeuiAnimatedSidebarItem.children] |
/// | Active `layoutId` pill | shared-layout active indicator |
/// | Mobile portal sheet | overlay sheet below [mobileBreakpoint] |
/// | `AnimatedSidebarTrigger` | [BeuiAnimatedSidebarTrigger] |
/// | Inset main | [child] |
///
/// ## Motion
///
/// - Desktop width springs with a component-local critically damped morph
///   spring (380 / 35 / 0.75) so it never overshoots the icon-rail boundary.
/// - Labels fade/slide on expand/collapse (`EASE_OUT`, exit faster than enter).
/// - Nested submenus clip-open with 180ms `EASE_OUT`.
/// - Active item indicator glides with [beuiSpringLayout].
/// - Mobile sheet slides with `EASE_DRAWER` (360ms); reduced motion fades.
///
/// Reduced motion: width snaps, labels fade without slide, submenu height
/// snaps, active indicator snaps, mobile sheet fades only.
class BeuiAnimatedSidebar extends StatefulWidget {
  /// Creates an animated sidebar shell.
  const BeuiAnimatedSidebar({
    required this.groups,
    this.expanded,
    this.defaultExpanded = true,
    this.onExpandedChange,
    this.openMobile,
    this.defaultOpenMobile = false,
    this.onOpenMobileChange,
    this.selectedId,
    this.defaultSelectedId,
    this.onSelected,
    this.header,
    this.footer,
    this.panelContent,
    this.child,
    this.side = BeuiAnimatedSidebarSide.left,
    this.variant = BeuiAnimatedSidebarVariant.sidebar,
    this.collapsible = BeuiAnimatedSidebarCollapsible.icon,
    this.width = kBeuiAnimatedSidebarWidth,
    this.iconWidth = kBeuiAnimatedSidebarIconWidth,
    this.mobileWidth = kBeuiAnimatedSidebarMobileWidth,
    this.mobileBreakpoint = kBeuiAnimatedSidebarMobileBreakpoint,
    this.semanticLabel = 'Sidebar',
    this.enableKeyboardShortcut = true,
    super.key,
  });

  /// Nav groups (top to bottom). Use a single unlabeled group for a flat list.
  final List<BeuiAnimatedSidebarGroup> groups;

  /// Desktop expanded state (controlled). When null, uses [defaultExpanded].
  final bool? expanded;

  /// Initial expanded state when uncontrolled.
  final bool defaultExpanded;

  /// Called when desktop expanded changes.
  final ValueChanged<bool>? onExpandedChange;

  /// Mobile sheet open state (controlled — source `openMobile`). When null the
  /// sidebar owns the state internally, seeded from [defaultOpenMobile].
  final bool? openMobile;

  /// Initial mobile sheet state when uncontrolled (source `defaultOpenMobile`,
  /// default `false`).
  final bool defaultOpenMobile;

  /// Called when the mobile sheet opens or closes (source
  /// `onOpenMobileChange`). Fires for the trigger, the ⌘/Ctrl+B shortcut, the
  /// barrier / close button, and the auto-close after selecting a destination.
  final ValueChanged<bool>? onOpenMobileChange;

  /// Selected item id (controlled).
  final String? selectedId;

  /// Initial selection when uncontrolled.
  final String? defaultSelectedId;

  /// Called when a leaf (or non-parent) item is selected.
  final ValueChanged<String>? onSelected;

  /// Optional header slot (logo / workspace switcher). Built with expanded
  /// context available via [BeuiAnimatedSidebarScope].
  final Widget? header;

  /// Optional footer slot (user card, etc.).
  final Widget? footer;

  /// Optional free-form slot inside the sidebar panel, below [groups] and
  /// above [footer] — the source's second `AnimatedSidebarGroup` holding
  /// arbitrary content (ai-sidebar's resource tree, for example). It is given
  /// the panel's remaining height so its own scroller can flex; [groups] then
  /// shrink-wrap above it. Null keeps the plain nav-only layout.
  final Widget? panelContent;

  /// Main content (source `AnimatedSidebarInset`). When null only the rail
  /// is rendered.
  final Widget? child;

  /// Edge the sidebar sits on.
  final BeuiAnimatedSidebarSide side;

  /// Desktop panel chrome — flush, floating card, or inset. Ignored on mobile.
  final BeuiAnimatedSidebarVariant variant;

  /// How the desktop sidebar collapses.
  final BeuiAnimatedSidebarCollapsible collapsible;

  /// Expanded desktop width.
  final double width;

  /// Collapsed icon-rail width.
  final double iconWidth;

  /// Mobile sheet width (capped at 88% of viewport).
  final double mobileWidth;

  /// Layout width below which mobile sheet mode activates.
  final double mobileBreakpoint;

  /// Accessibility label for the nav region / mobile dialog.
  final String semanticLabel;

  /// Whether ⌘/Ctrl+B toggles the sidebar (source default).
  final bool enableKeyboardShortcut;

  @override
  State<BeuiAnimatedSidebar> createState() => _BeuiAnimatedSidebarState();
}

class _BeuiAnimatedSidebarState extends State<BeuiAnimatedSidebar> {
  late bool _internalExpanded;
  late bool _internalOpenMobile;
  String? _internalSelected;
  final Set<String> _openSections = {};
  final GlobalKey _panelStackKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = {};
  Rect? _activeRect;
  late final FocusNode _shortcutFocus;

  bool get _controlledExpanded => widget.expanded != null;
  bool get _controlledOpenMobile => widget.openMobile != null;
  bool get _controlledSelected => widget.selectedId != null;

  bool get _expanded {
    if (widget.collapsible == BeuiAnimatedSidebarCollapsible.none) return true;
    return widget.expanded ?? _internalExpanded;
  }

  /// Mirrors `openMobile ?? internalOpenMobile` in the source provider.
  bool get _openMobile =>
      _controlledOpenMobile ? widget.openMobile! : _internalOpenMobile;

  String? get _selected {
    final id = _controlledSelected ? widget.selectedId : _internalSelected;
    if (id == null) return null;
    if (_findItem(id) != null) return id;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _internalExpanded = widget.defaultExpanded;
    _internalOpenMobile = widget.defaultOpenMobile;
    _internalSelected = widget.defaultSelectedId ?? _firstSelectableId();
    _shortcutFocus = FocusNode(debugLabel: 'beui_animated_sidebar_shortcut');
    _ensureItemKeys();
    // Open parent of default selection.
    final sel = _selected;
    if (sel != null) {
      final parent = _parentOf(sel);
      if (parent != null) _openSections.add(parent);
    }
  }

  @override
  void didUpdateWidget(BeuiAnimatedSidebar old) {
    super.didUpdateWidget(old);
    _ensureItemKeys();
    final sel = _selected;
    if (sel != null) {
      final parent = _parentOf(sel);
      if (parent != null && !_openSections.contains(parent)) {
        setState(() => _openSections.add(parent));
      }
    }
  }

  @override
  void dispose() {
    _shortcutFocus.dispose();
    super.dispose();
  }

  void _ensureItemKeys() {
    final ids = <String>{};
    for (final g in widget.groups) {
      for (final item in g.items) {
        ids.add(item.id);
        if (item.children != null) {
          for (final c in item.children!) {
            ids.add(c.id);
          }
        }
      }
    }
    _itemKeys.removeWhere((k, _) => !ids.contains(k));
    for (final id in ids) {
      _itemKeys.putIfAbsent(id, GlobalKey.new);
    }
  }

  String? _firstSelectableId() {
    for (final g in widget.groups) {
      for (final item in g.items) {
        if (item.disabled) continue;
        if (item.hasChildren) {
          for (final c in item.children!) {
            if (!c.disabled) return c.id;
          }
        } else {
          return item.id;
        }
      }
    }
    return null;
  }

  BeuiAnimatedSidebarItem? _findItem(String id) {
    for (final g in widget.groups) {
      for (final item in g.items) {
        if (item.id == id) return item;
        if (item.children != null) {
          for (final c in item.children!) {
            if (c.id == id) return c;
          }
        }
      }
    }
    return null;
  }

  String? _parentOf(String id) {
    for (final g in widget.groups) {
      for (final item in g.items) {
        if (item.children == null) continue;
        for (final c in item.children!) {
          if (c.id == id) return item.id;
        }
      }
    }
    return null;
  }

  void _setExpanded(bool next) {
    if (!_controlledExpanded) {
      setState(() => _internalExpanded = next);
    }
    widget.onExpandedChange?.call(next);
  }

  /// Same controlled/uncontrolled shape as [_setExpanded] (source `setOpenMobile`:
  /// only writes internal state when the prop is uncontrolled, always notifies).
  void _setOpenMobile(bool next) {
    if (!_controlledOpenMobile) {
      setState(() => _internalOpenMobile = next);
    }
    widget.onOpenMobileChange?.call(next);
  }

  void _toggle({required bool isMobile}) {
    if (isMobile) {
      _setOpenMobile(!_openMobile);
    } else {
      _setExpanded(!_expanded);
    }
  }

  void _select(String id, {required bool isMobile}) {
    final item = _findItem(id);
    if (item == null || item.disabled) return;

    if (item.hasChildren) {
      setState(() {
        if (_openSections.contains(id)) {
          _openSections.remove(id);
        } else {
          _openSections.add(id);
        }
      });
      return;
    }

    if (!_controlledSelected) {
      setState(() => _internalSelected = id);
    } else {
      setState(() {}); // refresh active rect after selection change
    }
    widget.onSelected?.call(id);

    // Auto-open parent section when a child is selected.
    final parent = _parentOf(id);
    if (parent != null && !_openSections.contains(parent)) {
      setState(() => _openSections.add(parent));
    }

    if (isMobile) _setOpenMobile(false);
  }

  void _scheduleActiveMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureActive();
    });
  }

  void _measureActive() {
    final id = _selected;
    if (id == null) {
      if (_activeRect != null) setState(() => _activeRect = null);
      return;
    }
    final stackBox =
        _panelStackKey.currentContext?.findRenderObject() as RenderBox?;
    final itemBox =
        _itemKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null ||
        itemBox == null ||
        !itemBox.hasSize ||
        !stackBox.hasSize) {
      return;
    }
    final topLeft = stackBox.globalToLocal(itemBox.localToGlobal(Offset.zero));
    final next = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      itemBox.size.width,
      itemBox.size.height,
    );
    if (_activeRect != next) {
      setState(() => _activeRect = next);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enableKeyboardShortcut) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isMod =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (!isMod || event.logicalKey != _shortcutKey) {
      return KeyEventResult.ignored;
    }
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < widget.mobileBreakpoint;
    _toggle(isMobile: isMobile);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < widget.mobileBreakpoint;
    final expanded = _expanded;
    final reduce = MediaQuery.disableAnimationsOf(context);

    _scheduleActiveMeasure();

    final scope = BeuiAnimatedSidebarScope(
      expanded: expanded,
      openMobile: _openMobile,
      isMobile: isMobile,
      toggle: () => _toggle(isMobile: isMobile),
      setExpanded: _setExpanded,
      setOpenMobile: _setOpenMobile,
      child: Focus(
        focusNode: _shortcutFocus,
        onKeyEvent: _onKey,
        canRequestFocus: false,
        skipTraversal: true,
        child: _buildShell(
          context: context,
          colors: colors,
          isMobile: isMobile,
          expanded: expanded,
          reduce: reduce,
        ),
      ),
    );

    return scope;
  }

  Widget _buildShell({
    required BuildContext context,
    required BeuiColors colors,
    required bool isMobile,
    required bool expanded,
    required bool reduce,
  }) {
    final panel = _SidebarPanel(
      key: beuiAnimatedSidebarPanelKey,
      stackKey: _panelStackKey,
      itemKeys: _itemKeys,
      groups: widget.groups,
      expanded: expanded || isMobile, // mobile sheet always shows labels
      selectedId: _selected,
      openSections: _openSections,
      activeRect: _activeRect,
      colors: colors,
      reduce: reduce,
      header: widget.header,
      footer: widget.footer,
      panelContent: widget.panelContent,
      semanticLabel: widget.semanticLabel,
      onSelect: (id) => _select(id, isMobile: isMobile),
      onCloseMobile: isMobile ? () => _setOpenMobile(false) : null,
    );

    if (isMobile) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.child != null) Positioned.fill(child: widget.child!),
          _MobileSheet(
            open: _openMobile,
            side: widget.side,
            width: widget.mobileWidth,
            colors: colors,
            reduce: reduce,
            semanticLabel: widget.semanticLabel,
            onDismiss: () => _setOpenMobile(false),
            child: panel,
          ),
        ],
      );
    }

    final targetWidth = switch (widget.collapsible) {
      BeuiAnimatedSidebarCollapsible.none => widget.width,
      BeuiAnimatedSidebarCollapsible.offcanvas => expanded ? widget.width : 0.0,
      BeuiAnimatedSidebarCollapsible.icon =>
        expanded ? widget.width : widget.iconWidth,
    };

    final rail = _DesktopRail(
      targetWidth: targetWidth,
      configuredWidth: widget.width,
      expanded: expanded,
      collapsible: widget.collapsible,
      side: widget.side,
      variant: widget.variant,
      colors: colors,
      reduce: reduce,
      onRailTap: () => _toggle(isMobile: false),
      child: panel,
    );

    final children = <Widget>[
      rail,
      if (widget.child != null)
        Expanded(
          child: _InsetContent(
            variant: widget.variant,
            side: widget.side,
            colors: colors,
            child: widget.child!,
          ),
        ),
    ];
    if (widget.side == BeuiAnimatedSidebarSide.right) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.reversed.toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop rail (width spring)
// ---------------------------------------------------------------------------

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.targetWidth,
    required this.configuredWidth,
    required this.expanded,
    required this.collapsible,
    required this.side,
    required this.variant,
    required this.colors,
    required this.reduce,
    required this.onRailTap,
    required this.child,
  });

  final double targetWidth;

  /// The consumer's configured [BeuiAnimatedSidebar.width] — the fallback
  /// used while the spring-animated width is transiently near zero (e.g.
  /// mid-offcanvas-open), instead of the library default.
  final double configuredWidth;
  final bool expanded;
  final BeuiAnimatedSidebarCollapsible collapsible;
  final BeuiAnimatedSidebarSide side;
  final BeuiAnimatedSidebarVariant variant;
  final BeuiColors colors;
  final bool reduce;
  final VoidCallback onRailTap;
  final Widget child;

  /// `sidebar` sits flush; `floating` / `inset` are detached cards inset by
  /// `m-2` on every edge (which is also what makes them `100svh - 1rem` tall).
  bool get _detached => variant != BeuiAnimatedSidebarVariant.sidebar;

  /// Source per-variant panel chrome:
  /// - `sidebar` → a single border on the inner edge, square, flat;
  /// - `floating` → `rounded-2xl border border-border shadow-sm`;
  /// - `inset` → `rounded-2xl` only (no border, no shadow).
  BoxDecoration get _decoration => BoxDecoration(
    color: colors.background,
    borderRadius: _detached
        ? BorderRadius.circular(_detachedRadius)
        : BorderRadius.zero,
    border: switch (variant) {
      BeuiAnimatedSidebarVariant.sidebar => Border(
        right: side == BeuiAnimatedSidebarSide.left
            ? BorderSide(color: colors.border)
            : BorderSide.none,
        left: side == BeuiAnimatedSidebarSide.right
            ? BorderSide(color: colors.border)
            : BorderSide.none,
      ),
      BeuiAnimatedSidebarVariant.floating => Border.all(color: colors.border),
      BeuiAnimatedSidebarVariant.inset => null,
    },
    boxShadow: variant == BeuiAnimatedSidebarVariant.floating
        ? _detachedShadow
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final motion = motionFor(
      context,
      _morphSpring,
      isMovement: true,
      reducedFallback: const NoMotion(),
    );

    return SingleMotionBuilder(
      value: targetWidth,
      motion: motion,
      builder: (context, w, _) {
        // NoMotion holds its value; reduced motion snaps directly to the target.
        final width = reduce ? targetWidth : w.clamp(0.0, double.infinity);
        final offcanvasHidden =
            collapsible == BeuiAnimatedSidebarCollapsible.offcanvas &&
            !expanded;
        // The rail reserves `width` in the Row; a detached panel gives back
        // `m-2` on each side, so the card itself is 16 narrower (and, via the
        // same Padding, 16 shorter — the source's `h-[calc(100svh-1rem)]`).
        final margin = _detached
            ? const EdgeInsets.all(_detachedMargin)
            : EdgeInsets.zero;
        final outer = width < 1 ? configuredWidth : width;
        final inner = (outer - margin.horizontal).clamp(0.0, double.infinity);
        final radius = _detached
            ? BorderRadius.circular(_detachedRadius)
            : BorderRadius.zero;

        return SizedBox(
          width: width,
          child: ClipRect(
            child: OverflowBox(
              alignment: side == BeuiAnimatedSidebarSide.left
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              minWidth: 0,
              maxWidth: targetWidth == 0
                  ? configuredWidth
                  : (width < 1 ? configuredWidth : null),
              child: AnimatedOpacity(
                duration: reduce
                    ? const Duration(milliseconds: 160)
                    : const Duration(milliseconds: 360),
                curve: beuiEaseDrawer,
                opacity: offcanvasHidden ? 0 : 1,
                child: Padding(
                  padding: margin,
                  child: DecoratedBox(
                    key: beuiAnimatedSidebarChromeKey,
                    decoration: _decoration,
                    child: ClipRRect(
                      borderRadius: radius,
                      child: SizedBox(
                        width: inner,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned.fill(child: child),
                            // Edge rail hit-target (source AnimatedSidebarRail).
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: side == BeuiAnimatedSidebarSide.left
                                  ? 0
                                  : null,
                              left: side == BeuiAnimatedSidebarSide.right
                                  ? 0
                                  : null,
                              width: 12,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeColumn,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: onRailTap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Inset content surface (source `AnimatedSidebarInset`)
// ---------------------------------------------------------------------------

/// Wraps [BeuiAnimatedSidebar.child]. Only the `inset` variant gives it chrome:
/// source `md:peer-data-[variant=inset]:m-2 …:ml-0 …:rounded-2xl …:shadow-sm`.
///
/// The source hardcodes `ml-0` because its inset sits to the *right* of a
/// left-hand sidebar; the margin is dropped on the edge the sidebar already
/// spaced with its own `m-2`, so this port resolves that edge from [side]
/// rather than pinning it to the left.
class _InsetContent extends StatelessWidget {
  const _InsetContent({
    required this.variant,
    required this.side,
    required this.colors,
    required this.child,
  });

  final BeuiAnimatedSidebarVariant variant;
  final BeuiAnimatedSidebarSide side;
  final BeuiColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (variant != BeuiAnimatedSidebarVariant.inset) return child;

    final onLeft = side == BeuiAnimatedSidebarSide.left;
    final radius = BorderRadius.circular(_detachedRadius);
    return Padding(
      padding: EdgeInsets.only(
        left: onLeft ? 0 : _detachedMargin,
        right: onLeft ? _detachedMargin : 0,
        top: _detachedMargin,
        bottom: _detachedMargin,
      ),
      child: DecoratedBox(
        key: beuiAnimatedSidebarInsetKey,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: radius,
          boxShadow: _detachedShadow,
        ),
        child: ClipRRect(borderRadius: radius, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile sheet
// ---------------------------------------------------------------------------

class _MobileSheet extends StatelessWidget {
  const _MobileSheet({
    required this.open,
    required this.side,
    required this.width,
    required this.colors,
    required this.reduce,
    required this.semanticLabel,
    required this.onDismiss,
    required this.child,
  });

  final bool open;
  final BeuiAnimatedSidebarSide side;
  final double width;
  final BeuiColors colors;
  final bool reduce;
  final String semanticLabel;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.88;
    final panelW = width.clamp(0.0, maxW);
    final isLeft = side == BeuiAnimatedSidebarSide.left;

    final slideMotion = motionFor(
      context,
      _panelSlide,
      isMovement: true,
      reducedFallback: _reducedMotion,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Barrier
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !open,
            child: SingleMotionBuilder(
              value: open ? 1.0 : 0.0,
              motion: reduce ? _reducedMotion : _panelSlide,
              builder: (context, t, _) {
                if (t <= 0.001) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: ColoredBox(
                    color: const Color(0x66000000).withValues(alpha: 0.4 * t),
                  ),
                );
              },
            ),
          ),
        ),
        // Panel
        SingleMotionBuilder(
          value: open ? 1.0 : 0.0,
          motion: slideMotion,
          builder: (context, t, _) {
            final progress = t.clamp(0.0, 1.0);
            if (!open && progress <= 0.001) {
              return const SizedBox.shrink();
            }
            final dx = reduce
                ? 0.0
                : (isLeft ? -1.0 : 1.0) * panelW * (1 - progress);
            final opacity = reduce ? progress : 1.0;

            return Align(
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(dx, 0),
                  child: Material(
                    key: beuiAnimatedSidebarMobilePanelKey,
                    elevation: 16,
                    color: colors.background,
                    child: Semantics(
                      namesRoute: true,
                      scopesRoute: true,
                      label: semanticLabel,
                      explicitChildNodes: true,
                      child: SizedBox(
                        width: panelW,
                        height: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.background,
                            border: Border(
                              right: isLeft
                                  ? BorderSide(color: colors.border)
                                  : BorderSide.none,
                              left: isLeft
                                  ? BorderSide.none
                                  : BorderSide(color: colors.border),
                            ),
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Panel body (header / groups / footer)
// ---------------------------------------------------------------------------

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    required this.stackKey,
    required this.itemKeys,
    required this.groups,
    required this.expanded,
    required this.selectedId,
    required this.openSections,
    required this.activeRect,
    required this.colors,
    required this.reduce,
    required this.semanticLabel,
    required this.onSelect,
    this.header,
    this.footer,
    this.panelContent,
    this.onCloseMobile,
    super.key,
  });

  final GlobalKey stackKey;
  final Map<String, GlobalKey> itemKeys;
  final List<BeuiAnimatedSidebarGroup> groups;
  final bool expanded;
  final String? selectedId;
  final Set<String> openSections;
  final Rect? activeRect;
  final BeuiColors colors;
  final bool reduce;
  final String semanticLabel;
  final ValueChanged<String> onSelect;
  final Widget? header;
  final Widget? footer;
  final Widget? panelContent;
  final VoidCallback? onCloseMobile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null || onCloseMobile != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  if (header != null) Expanded(child: header!),
                  if (onCloseMobile != null)
                    IconButton(
                      tooltip: 'Close sidebar',
                      onPressed: onCloseMobile,
                      icon: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: colors.mutedForeground,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ),
          // With a [panelContent] slot the nav groups shrink-wrap and the
          // free-form content takes the remaining height (source: group 1 is
          // `shrink-0`, group 2 is `min-h-0 flex-1`). Without it the nav list
          // keeps the whole panel, exactly as before.
          Flexible(
            fit: panelContent == null ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Stack(
                key: stackKey,
                children: [
                  if (activeRect != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _ActivePill(
                          rect: activeRect!,
                          colors: colors,
                          reduce: reduce,
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var gi = 0; gi < groups.length; gi++) ...[
                        // Source `AnimatedSidebarContent` is `gap-2` — 8
                        // *between* groups, never trailing the last one.
                        if (gi > 0) const SizedBox(height: 8),
                        Padding(
                          // Source `AnimatedSidebarGroup`: `px-1 py-1.5`.
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (groups[gi].label != null)
                                _GroupLabel(
                                  label: groups[gi].label!,
                                  expanded: expanded,
                                  colors: colors,
                                  reduce: reduce,
                                ),
                              for (
                                var ii = 0;
                                ii < groups[gi].items.length;
                                ii++
                              ) ...[
                                // Source `AnimatedSidebarMenu`: `gap-0.5` — 2.
                                if (ii > 0) const SizedBox(height: 2),
                                _MenuItem(
                                  item: groups[gi].items[ii],
                                  itemKeys: itemKeys,
                                  expanded: expanded,
                                  selectedId: selectedId,
                                  open: openSections.contains(
                                    groups[gi].items[ii].id,
                                  ),
                                  colors: colors,
                                  reduce: reduce,
                                  onSelect: onSelect,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (panelContent != null) Expanded(child: panelContent!),
          if (footer != null)
            Padding(
              // Source `AnimatedSidebarFooter`: `p-3` — 12 on every edge.
              padding: const EdgeInsets.all(12),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active pill (source layoutId shared-layout indicator)
// ---------------------------------------------------------------------------

class _ActivePill extends StatelessWidget {
  const _ActivePill({
    required this.rect,
    required this.colors,
    required this.reduce,
  });

  final Rect rect;
  final BeuiColors colors;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final motion = motionFor(
      context,
      beuiSpringLayout,
      isMovement: true,
      reducedFallback: const NoMotion(),
    );

    final pill = DecoratedBox(
      key: beuiAnimatedSidebarActiveKey,
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    if (reduce || motion is NoMotion) {
      return _positioned(rect, pill);
    }

    return MotionBuilder<Rect>(
      value: rect,
      motion: motion,
      converter: const RectMotionConverter(),
      builder: (context, r, _) => _positioned(r, pill),
    );
  }

  Widget _positioned(Rect r, Widget pill) => Stack(
    children: [
      Positioned(
        left: r.left,
        top: r.top,
        width: r.width,
        height: r.height,
        child: pill,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Group label
// ---------------------------------------------------------------------------

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({
    required this.label,
    required this.expanded,
    required this.colors,
    required this.reduce,
  });

  final String label;
  final bool expanded;
  final BeuiColors colors;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: reduce ? _labelExit : (expanded ? _labelEnter : _labelExit),
      curve: beuiEaseOut,
      opacity: expanded ? 1 : 0,
      // Source `AnimatedSidebarGroupLabel`: `mb-1 h-7 px-2` — a fixed 28-tall
      // box with a 4 bottom margin. It carries no top padding of its own.
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
        child: SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.4,
                color: colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu item + submenu
// ---------------------------------------------------------------------------

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.item,
    required this.itemKeys,
    required this.expanded,
    required this.selectedId,
    required this.open,
    required this.colors,
    required this.reduce,
    required this.onSelect,
  });

  final BeuiAnimatedSidebarItem item;
  final Map<String, GlobalKey> itemKeys;
  final bool expanded;
  final String? selectedId;
  final bool open;
  final BeuiColors colors;
  final bool reduce;
  final ValueChanged<String> onSelect;

  bool get _isActive {
    if (selectedId == item.id) return true;
    if (item.children == null) return false;
    return item.children!.any((c) => c.id == selectedId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MenuButton(
          key: itemKeys[item.id],
          item: item,
          expanded: expanded,
          isActive: _isActive,
          isSectionOpen: item.hasChildren ? open : null,
          colors: colors,
          reduce: reduce,
          onTap: item.disabled ? null : () => onSelect(item.id),
        ),
        if (item.hasChildren)
          _Submenu(
            open: open && expanded,
            children: item.children!,
            itemKeys: itemKeys,
            selectedId: selectedId,
            colors: colors,
            reduce: reduce,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.item,
    required this.expanded,
    required this.isActive,
    required this.isSectionOpen,
    required this.colors,
    required this.reduce,
    required this.onTap,
    super.key,
  });

  final BeuiAnimatedSidebarItem item;
  final bool expanded;
  final bool isActive;
  final bool? isSectionOpen;
  final BeuiColors colors;
  final bool reduce;
  final VoidCallback? onTap;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = widget.colors;
    final fg = (widget.isActive || _hovered)
        ? colors.foreground
        : colors.mutedForeground;

    // Source: a `size-5` (20) grid cell holding a `size-4` (16) glyph.
    final icon = SizedBox(
      width: 20,
      height: 20,
      child: item.icon != null
          ? Center(child: Icon(item.icon, size: 16, color: fg))
          : null,
    );

    // The source row keeps its `px-3` layout at every width: the icon stays
    // anchored 24 from the panel edge and the narrowing rail closes around it,
    // landing the glyph dead-centre of the 68 icon rail by arithmetic
    // (8 content + 4 group + 12 row + 10 half-icon = 34 = 68 / 2). Only the
    // label, badge and chevron come and go. Never re-centre the icon: that
    // makes it jump to the middle of a still-wide panel mid-morph.
    // Source `min-h-9`, single-line label: always exactly 36 tall.
    Widget row = SizedBox(
      height: 36,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Stand-in for the source's `overflow-hidden`. CSS clips whatever
          // does not fit the closing rail; a Flutter Row throws instead, so
          // this does the clipping explicitly. Two cases need it:
          //
          //  * `expanded` flips a whole width spring before the rail is wide
          //    enough for the trailing badge/chevron — gate those on measured
          //    width (never the icon, which must keep its `px-3` anchor);
          //  * the `floating` variant's icon rail is 52 wide once `m-2` is
          //    taken out, leaving the row 4 for a 20 icon. The source clips
          //    there too, so hold a 44 floor and clip the overflow.
          final trailingFits = constraints.maxWidth >= 96;
          final w = constraints.maxWidth < 44 ? 44.0 : constraints.maxWidth;
          return ClipRect(
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: w,
              maxWidth: w,
              minHeight: 36,
              maxHeight: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    icon,
                    // `flex-1 truncate`: the label absorbs the slack and shrinks to
                    // zero as the rail closes, so the row never overflows.
                    Expanded(
                      child: _CollapsingLabel(
                        expanded: widget.expanded,
                        reduce: widget.reduce,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: fg,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Source row is a single `gap-2.5` flex, so the badge and the
                    // chevron are each 10 clear of the label, not 4 and 0.
                    // Source drops the badge outright while collapsed
                    // (`badge && !panel.collapsed`).
                    if (item.badge != null && widget.expanded && trailingFits)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          item.badge!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    if (widget.isSectionOpen != null && trailingFits)
                      // Source keeps the chevron mounted and fades it
                      // (`opacity: collapsed ? 0 : 1`); collapsing its width in
                      // step is what `overflow-hidden` buys the source for free.
                      ClipRect(
                        child: AnimatedAlign(
                          duration: widget.reduce
                              ? _labelExit
                              : (widget.expanded ? _labelEnter : _labelExit),
                          curve: beuiEaseOut,
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: widget.expanded ? 1.0 : 0.0,
                          child: _CollapsingLabel(
                            expanded: widget.expanded,
                            reduce: widget.reduce,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: SingleMotionBuilder(
                                value: widget.isSectionOpen! ? 1.0 : 0.0,
                                motion: motionFor(
                                  context,
                                  beuiSpringLayout,
                                  isMovement: true,
                                  reducedFallback: const NoMotion(),
                                ),
                                builder: (context, t, _) {
                                  // Source: a `size-4` (16) cell holding a
                                  // `size-3.5` (14) chevron.
                                  return SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Center(
                                      child: Transform.rotate(
                                        angle: t * math.pi / 2,
                                        child: Icon(
                                          LucideIcons.chevron_right,
                                          size: 14,
                                          color: colors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    // Press scale (source whileTap scale 0.98).
    row = SingleMotionBuilder(
      value: _pressed && !widget.reduce && widget.onTap != null ? 0.98 : 1.0,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: row,
    );

    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: item.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Opacity(opacity: item.disabled ? 0.4 : 1, child: row),
      ),
    );

    return Tooltip(
      message: widget.expanded ? '' : item.label,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        enabled: !item.disabled,
        selected: widget.isActive,
        expanded: widget.isSectionOpen,
        label: item.label,
        child: button,
      ),
    );
  }
}

class _CollapsingLabel extends StatelessWidget {
  const _CollapsingLabel({
    required this.expanded,
    required this.reduce,
    required this.child,
  });

  final bool expanded;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Exit faster than enter; delay enter slightly to ride the width spring.
    final duration = reduce
        ? _labelExit
        : (expanded ? _labelEnter : _labelExit);
    final delay = (!reduce && expanded) ? _labelEnterDelay : Duration.zero;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: expanded ? 1.0 : 0.0),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds == 0
            ? 0
            : delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: beuiEaseOut,
      ),
      builder: (context, t, child) {
        return IgnorePointer(
          ignoring: t < 0.5,
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(reduce ? 0 : (1 - t) * -4, 0),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _Submenu extends StatelessWidget {
  const _Submenu({
    required this.open,
    required this.children,
    required this.itemKeys,
    required this.selectedId,
    required this.colors,
    required this.reduce,
    required this.onSelect,
  });

  final bool open;
  final List<BeuiAnimatedSidebarItem> children;
  final Map<String, GlobalKey> itemKeys;
  final String? selectedId;
  final BeuiColors colors;
  final bool reduce;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final list = Padding(
      padding: const EdgeInsets.only(left: 20, top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in children)
                _SubButton(
                  key: itemKeys[child.id],
                  item: child,
                  isActive: selectedId == child.id,
                  colors: colors,
                  reduce: reduce,
                  onTap: child.disabled ? null : () => onSelect(child.id),
                ),
            ],
          ),
        ),
      ),
    );

    if (reduce) {
      // Movement (the height collapse below) drops under reduced motion;
      // opacity stays, so the list stays mounted and only fades.
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: open ? 1 : 0,
        child: list,
      );
    }

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: beuiEaseOut,
        alignment: Alignment.topCenter,
        child: open ? list : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

class _SubButton extends StatefulWidget {
  const _SubButton({
    required this.item,
    required this.isActive,
    required this.colors,
    required this.reduce,
    required this.onTap,
    super.key,
  });

  final BeuiAnimatedSidebarItem item;
  final bool isActive;
  final BeuiColors colors;
  final bool reduce;
  final VoidCallback? onTap;

  @override
  State<_SubButton> createState() => _SubButtonState();
}

class _SubButtonState extends State<_SubButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final fg = widget.isActive || _hovered
        ? colors.foreground
        : colors.mutedForeground;

    Widget body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Dot / optional icon
            if (widget.item.icon != null)
              Icon(widget.item.icon, size: 14, color: fg)
            else
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isActive) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: body,
      );
    }

    body = SingleMotionBuilder(
      value: _pressed && !widget.reduce && widget.onTap != null ? 0.98 : 1.0,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: body,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.item.disabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: widget.onTap == null
              ? null
              : (_) => setState(() => _pressed = false),
          onTapCancel: widget.onTap == null
              ? null
              : () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: Opacity(
            opacity: widget.item.disabled ? 0.4 : 1,
            child: Semantics(
              button: true,
              selected: widget.isActive,
              label: widget.item.label,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
