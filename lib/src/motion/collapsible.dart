import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show CurvedMotion, Motion, SingleMotionBuilder;

int _nextCollapsibleId = 0;

/// A composable disclosure with measured, spring-driven content height.
///
/// Supply [open] and [onOpenChange] for controlled use, or omit [open] and
/// seed the internal state with [defaultOpen]. Place a
/// [BeuiCollapsibleTrigger] and [BeuiCollapsibleContent] in [child].
class BeuiCollapsible extends StatefulWidget {
  /// Creates a composable collapsible section.
  const BeuiCollapsible({
    required this.child,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.disabled = false,
    super.key,
  });

  /// Controlled open state. When null, the widget manages its own state.
  final bool? open;

  /// Initial state when [open] is null.
  final bool defaultOpen;

  /// Called when a user requests a state change.
  final ValueChanged<bool>? onOpenChange;

  /// Whether the trigger is disabled.
  final bool disabled;

  /// The trigger and content widgets.
  final Widget child;

  @override
  State<BeuiCollapsible> createState() => _BeuiCollapsibleState();
}

class _BeuiCollapsibleState extends State<BeuiCollapsible> {
  late final String _identifier = 'beui-collapsible-${_nextCollapsibleId++}';
  String get _triggerIdentifier => '$_identifier-trigger';
  String get _contentIdentifier => '$_identifier-content';
  late bool _internalOpen = widget.defaultOpen;
  final FocusNode _triggerFocusNode = FocusNode(
    debugLabel: 'collapsible trigger',
  );
  final FocusScopeNode _contentFocusScope = FocusScopeNode(
    debugLabel: 'collapsible content',
  );
  double _contentHeight = 0;

  bool get isOpen => widget.open ?? _internalOpen;

  void toggle() => setOpen(!isOpen);

  void setOpen(bool next) {
    if (widget.disabled || next == isOpen) return;
    if (isOpen && !next && _contentFocusScope.hasFocus) {
      _triggerFocusNode.requestFocus();
    }
    if (widget.open == null) setState(() => _internalOpen = next);
    widget.onOpenChange?.call(next);
  }

  void reportContentHeight(double height) {
    if ((height - _contentHeight).abs() < 0.5) return;
    setState(() => _contentHeight = height);
  }

  @override
  void dispose() {
    _triggerFocusNode.dispose();
    _contentFocusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _CollapsibleScope(state: this, child: widget.child);
}

class _CollapsibleScope extends InheritedWidget {
  const _CollapsibleScope({required this.state, required super.child});

  final _BeuiCollapsibleState state;

  static _BeuiCollapsibleState of(BuildContext context, String component) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CollapsibleScope>();
    assert(scope != null, '$component must be used inside BeuiCollapsible.');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(_CollapsibleScope oldWidget) => true;
}

/// An accessible button that toggles its enclosing [BeuiCollapsible].
class BeuiCollapsibleTrigger extends StatelessWidget {
  /// Creates a collapsible trigger.
  const BeuiCollapsibleTrigger({required this.child, super.key});

  /// Trigger content, commonly a label and [BeuiCollapsibleIndicator].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = _CollapsibleScope.of(context, 'BeuiCollapsibleTrigger');
    final colors = BeuiColors.resolve(context);
    final enabled = !state.widget.disabled;
    final action = CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        state.toggle();
        return null;
      },
    );

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{ActivateIntent: action},
        child: MergeSemantics(
          child: Semantics(
            container: true,
            identifier: state._triggerIdentifier,
            controlsNodes: <String>{state._contentIdentifier},
            button: true,
            enabled: enabled,
            expanded: state.isOpen,
            onTap: enabled ? state.toggle : null,
            child: FocusableActionDetector(
              enabled: enabled,
              focusNode: state._triggerFocusNode,
              mouseCursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? state.toggle : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: colors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Measured content for a [BeuiCollapsible], hidden from focus and semantics
/// while closed.
class BeuiCollapsibleContent extends StatefulWidget {
  /// Creates the collapsible content region.
  const BeuiCollapsibleContent({required this.child, super.key});

  /// Content revealed when the enclosing collapsible is open.
  final Widget child;

  @override
  State<BeuiCollapsibleContent> createState() => _BeuiCollapsibleContentState();
}

class _BeuiCollapsibleContentState extends State<BeuiCollapsibleContent> {
  final GlobalKey _measureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(BeuiCollapsibleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final renderBox =
        _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    _CollapsibleScope.of(
      context,
      'BeuiCollapsibleContent',
    ).reportContentHeight(renderBox.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final state = _CollapsibleScope.of(context, 'BeuiCollapsibleContent');
    final reduce = MediaQuery.disableAnimationsOf(context);
    final heightTarget = state.isOpen ? state._contentHeight : 0.0;
    final heightMotion = motionFor(context, beuiSpringLayout, isMovement: true);
    final fadeMotion = motionFor(
      context,
      const CurvedMotion(Duration(milliseconds: 180), beuiEaseOut),
      isMovement: false,
    );

    Widget clipped(double height) => ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: state._contentHeight > 0
            ? (height / state._contentHeight).clamp(0.0, 1.0)
            : (height > 0 ? 1.0 : 0.0),
        child: FocusScope(
          node: state._contentFocusScope,
          child: KeyedSubtree(
            key: _measureKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: childWithFade(state, fadeMotion),
            ),
          ),
        ),
      ),
    );

    final content = reduce
        ? clipped(heightTarget)
        : SingleMotionBuilder(
            value: heightTarget,
            motion: heightMotion,
            builder: (context, height, _) => clipped(height),
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      hidden: !state.isOpen,
      identifier: state._contentIdentifier,
      child: ExcludeSemantics(
        excluding: !state.isOpen,
        child: ExcludeFocus(
          excluding: !state.isOpen,
          child: IgnorePointer(ignoring: !state.isOpen, child: content),
        ),
      ),
    );
  }

  Widget childWithFade(_BeuiCollapsibleState state, Motion fadeMotion) =>
      SingleMotionBuilder(
        value: state.isOpen ? 1.0 : 0.0,
        motion: fadeMotion,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 14,
            height: 24 / 14,
            color: BeuiColors.resolve(context).mutedForeground,
          ),
          child: widget.child,
        ),
      );
}

/// A chevron that rotates with its enclosing [BeuiCollapsible].
class BeuiCollapsibleIndicator extends StatelessWidget {
  /// Creates the default Lucide chevron indicator.
  const BeuiCollapsibleIndicator({this.size = 16, super.key});

  /// Indicator edge length.
  final double size;

  @override
  Widget build(BuildContext context) {
    final state = _CollapsibleScope.of(context, 'BeuiCollapsibleIndicator');
    final reduce = MediaQuery.disableAnimationsOf(context);
    final angle = state.isOpen ? math.pi : 0.0;
    final icon = Icon(
      LucideIcons.chevron_down,
      size: size,
      color: BeuiColors.resolve(context).mutedForeground,
    );
    if (reduce) {
      return ExcludeSemantics(
        child: Transform.rotate(angle: angle, child: icon),
      );
    }
    return ExcludeSemantics(
      child: SingleMotionBuilder(
        value: angle,
        motion: motionFor(context, beuiSpringLayout, isMovement: true),
        builder: (context, value, child) =>
            Transform.rotate(angle: value, child: child),
        child: icon,
      ),
    );
  }
}
