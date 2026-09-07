import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// ---------------------------------------------------------------------------
// BeuiChatApp
// ---------------------------------------------------------------------------

/// A complete agent conversation workspace shell — the Flutter port of
/// beUI's `chat-app`.
///
/// Source `ChatApp` is a thin `AnimatedSidebarProvider` wrapper with a
/// rounded bordered surface and a CSS `--sidebar-width` token. This port is a
/// reusable high-level layout that composes:
///
/// * optional [sidebar] (typically [BeuiAiSidebar] or a nav column)
/// * optional [header] (title, status, sidebar trigger)
/// * required [body] (typically [BeuiMessageScroller] with messages)
/// * optional [prompt] (typically [BeuiPromptInput])
///
/// The shell owns chrome only — border, radius, column flex, and the optional
/// sidebar column. Conversation content, streaming, tools, and input state
/// stay with the consumer (see the gallery demo for a full agent turn).
///
/// ## Narrow windows
///
/// Below [sidebarBreakpoint] the sidebar leaves the flow. The source
/// hardcodes a 272px rail with no responsive behaviour at all, which on a
/// 300px window left the conversation 28px — narrow enough to trip the message
/// bubble's own minimum-width assert. Below the breakpoint the sidebar either
/// hides (the default) or slides in over the transcript when [sidebarOpen] is
/// true, dismissible through [onSidebarDismiss].
///
/// ```dart
/// BeuiChatApp(
///   sidebar: BeuiAiSidebar(...),
///   sidebarOpen: _drawerOpen,
///   onSidebarDismiss: () => setState(() => _drawerOpen = false),
///   header: Text('Checkout release'),
///   body: BeuiMessageScroller(child: BeuiMessageGroup(...)),
///   prompt: BeuiPromptInput(onSubmit: ...),
/// )
/// ```
class BeuiChatApp extends StatelessWidget {
  /// Creates an agent workspace shell.
  const BeuiChatApp({
    required this.body,
    this.sidebar,
    this.header,
    this.prompt,
    this.sidebarWidth = kBeuiChatAppSidebarWidth,
    this.sidebarBreakpoint = kBeuiChatAppSidebarBreakpoint,
    this.sidebarOpen,
    this.onSidebarDismiss,
    this.borderRadius,
    this.showBorder = true,
    this.backgroundColor,
    this.avoidKeyboardInset = true,
    this.semanticLabel = 'Agent workspace',
    super.key,
  }) : assert(sidebarWidth > 0),
       assert(sidebarBreakpoint >= 0);

  /// Source default sidebar width — `17rem` ≈ 272 logical px.
  static const double kBeuiChatAppSidebarWidth = 272;

  /// Width below which the sidebar collapses out of the flow.
  ///
  /// 768 is the conventional tablet breakpoint and leaves ~496px for the
  /// conversation at the default [kBeuiChatAppSidebarWidth].
  static const double kBeuiChatAppSidebarBreakpoint = 768;

  /// Main conversation region (source `AnimatedSidebarInset` body).
  ///
  /// Typically a [BeuiMessageScroller] wrapping a [BeuiMessageGroup]. Takes
  /// all remaining vertical space between [header] and [prompt].
  final Widget body;

  /// Optional left rail (source `AnimatedSidebar` panel).
  ///
  /// Pass a [BeuiAiSidebar], a custom nav column, or any widget. When null the
  /// shell is a single-column chat surface.
  final Widget? sidebar;

  /// Optional top chrome above [body] (title, status chip, triggers).
  final Widget? header;

  /// Optional composer pinned under [body] (source prompt footer).
  final Widget? prompt;

  /// Width of [sidebar] when present (source `--sidebar-width`, default
  /// [kBeuiChatAppSidebarWidth]).
  final double sidebarWidth;

  /// Shell width below which [sidebar] leaves the flow (default
  /// [kBeuiChatAppSidebarBreakpoint]). Pass 0 to keep the sidebar inline at
  /// every size — the pre-UX-pass behaviour.
  final double sidebarBreakpoint;

  /// Whether the collapsed sidebar is shown as an overlay drawer.
  ///
  /// Only consulted below [sidebarBreakpoint]; above it the sidebar is always
  /// inline. Null (the default) means "hidden when collapsed", so a shell that
  /// never wires a trigger degrades to a single conversation column instead of
  /// crushing it.
  final bool? sidebarOpen;

  /// Called when the reader dismisses the overlay sidebar — scrim tap or Esc.
  final VoidCallback? onSidebarDismiss;

  /// Corner radius of the outer shell. Null uses [BeuiAgentShapes.cardRadius]
  /// (source `rounded-2xl` = 16).
  final double? borderRadius;

  /// Whether to paint the hairline outer border (source `border border-border`).
  final bool showBorder;

  /// Shell fill. Defaults to [BeuiColors.background].
  final Color? backgroundColor;

  /// Lifts [prompt] clear of the soft keyboard (default true).
  ///
  /// The shell pins the composer to its own bottom edge, so outside a resizing
  /// `Scaffold` the keyboard covered the thing the reader was typing into. The
  /// inset is consumed here and removed from the subtree, so a nested
  /// `MediaQuery` consumer cannot apply it a second time.
  final bool avoidKeyboardInset;

  /// Accessible label for the workspace region.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final agent = BeuiAgentTheme.of(context);
    final bg = backgroundColor ?? colors.background;
    final radius = borderRadius ?? agent.shapes.cardRadius;
    // The rail's divider is on its *trailing* edge, which is the right in
    // LTR and the left in RTL.
    final borderSide = BorderSide(
      color: colors.border,
      width: agent.structure.borderWidth,
    );

    final keyboardInset = avoidKeyboardInset
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    Widget composer(Widget child) {
      if (keyboardInset <= 0) return child;
      // Consume the inset here and strip it below, so a nested consumer (a
      // `BeuiPromptInput` in a `Scaffold`, say) cannot double-apply it.
      return MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: child,
        ),
      );
    }

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          header!,
          Divider(
            height: 1,
            thickness: agent.structure.borderWidth,
            color: colors.border,
          ),
        ],
        Expanded(child: body),
        if (prompt != null) ...[
          Divider(
            height: 1,
            thickness: agent.structure.borderWidth,
            color: colors.border,
          ),
          composer(prompt!),
        ],
      ],
    );

    final rail = sidebar == null
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(
              border: BorderDirectional(end: borderSide),
            ),
            child: sidebar,
          );

    final shell = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final collapsed =
            rail != null && width.isFinite && width < sidebarBreakpoint;

        if (rail == null) return mainColumn;

        if (!collapsed) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: sidebarWidth, child: rail),
              Expanded(child: mainColumn),
            ],
          );
        }

        // Collapsed: the conversation gets the whole shell, and the rail
        // becomes an overlay drawer over it when asked for.
        final open = sidebarOpen ?? false;
        return Stack(
          children: [
            Positioned.fill(child: mainColumn),
            if (sidebarOpen != null)
              _SidebarDrawer(
                open: open,
                width: sidebarWidth > width ? width * 0.86 : sidebarWidth,
                scrimColor: colors.foreground.withValues(alpha: 0.32),
                onDismiss: onSidebarDismiss,
                child: ColoredBox(color: colors.background, child: rail),
              ),
          ],
        );
      },
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: showBorder
              ? Border.all(
                  color: colors.border,
                  width: agent.structure.borderWidth,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: shell,
        ),
      ),
    );
  }
}

/// The collapsed sidebar, as a scrimmed drawer inside the shell.
///
/// Deliberately *not* routed through the root overlay: the shell is a bordered,
/// clipped surface that is frequently embedded inside a page, and a drawer that
/// escaped it would cover unrelated UI.
class _SidebarDrawer extends StatelessWidget {
  const _SidebarDrawer({
    required this.open,
    required this.width,
    required this.scrimColor,
    required this.onDismiss,
    required this.child,
  });

  final bool open;
  final double width;
  final Color scrimColor;
  final VoidCallback? onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    // Scrim opacity always transitions (`motionFor` never drops a
    // non-movement channel) — that makes it the single safe source for both
    // the scrim fade and the drawer's visibility gate below, so nothing
    // re-derives the open/close target a second time.
    final scrimMotion = motionFor(
      context,
      const CurvedMotion(Duration(milliseconds: 160), beuiEaseOut),
      isMovement: false,
    );
    // Panel travel is movement, so reduced motion drops it. `NoMotion` would
    // freeze at whichever value it was seeded with rather than reaching the
    // target (see `_no_motion_semantics_test.dart`), so the drop is applied
    // in the builder below instead of trusted to the motion.
    final panelMotion = motionFor(
      context,
      open
          ? const CurvedMotion(Duration(milliseconds: 220), beuiEaseOut)
          : const CurvedMotion(Duration(milliseconds: 140), beuiEaseOut),
      isMovement: true,
    );

    final panel = FocusScope(
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.escape):
              const DismissIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                onDismiss?.call();
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );

    return SingleMotionBuilder(
      value: open ? 1.0 : 0.0,
      motion: scrimMotion,
      builder: (context, t, stackChild) {
        final v = t.clamp(0.0, 1.0);
        if (v <= 0.001) return const SizedBox.shrink();
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: 'Close navigation',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: ColoredBox(
                      color: scrimColor.withValues(alpha: scrimColor.a * v),
                    ),
                  ),
                ),
              ),
              SingleMotionBuilder(
                value: open ? 1.0 : 0.0,
                motion: panelMotion,
                builder: (context, panelT, panelChild) {
                  final s = reduce
                      ? (open ? 1.0 : 0.0)
                      : panelT.clamp(0.0, 1.0);
                  return PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    start: -width * (1 - s),
                    width: width,
                    child: panelChild!,
                  );
                },
                child: stackChild,
              ),
            ],
          ),
        );
      },
      child: panel,
    );
  }
}
