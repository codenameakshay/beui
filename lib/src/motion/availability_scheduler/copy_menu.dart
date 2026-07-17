import 'dart:async';

import 'package:flutter/material.dart';

import '../../overlay/beui_overlay.dart';
import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';
import '../checkbox.dart';
import '../tooltip.dart';
import 'icon_button.dart';
import 'types.dart';

/// Copy this day's hours to other days — the Flutter port of the scheduler's
/// `copy-menu.tsx`.
///
/// The source uses the library `MorphPopover`; this port has no morph-popover
/// widget, so it anchors an equivalent day-picker panel on the shared
/// [BeuiOverlay] (root overlay, Esc / tap-outside dismiss). The trigger is a
/// [SchedulerIconButton] whose glyph swaps Copy → Check for 1200ms after an
/// apply (source `setTimeout(…, 1200)`); the swap scales `0.5 → 1` with a fade.
/// The panel springs open on `SPRING_PANEL` ([beuiSpringPanel]) with a day
/// checklist plus "Every day" / "Apply" actions.
///
/// Reduced motion drops the glyph-swap scale and the panel scale/offset (opacity
/// only).
///
/// Internal to the scheduler — not part of the public surface.
class CopyMenu extends StatefulWidget {
  /// Creates a copy menu for the day labelled [fromLabel] (excluded from the
  /// target list).
  const CopyMenu({
    required this.fromLabel,
    required this.onApply,
    super.key,
  });

  /// Label of the source day (its row's day, excluded from the picker).
  final String fromLabel;

  /// Applies this day's hours to [targets].
  final ValueChanged<List<BeuiDayKey>> onApply;

  @override
  State<CopyMenu> createState() => _CopyMenuState();
}

class _CopyMenuState extends State<CopyMenu> {
  bool _open = false;
  bool _copied = false;
  final Set<BeuiDayKey> _picked = <BeuiDayKey>{};
  Timer? _copiedTimer;

  List<BeuiDayKey> get _others =>
      BeuiDayKey.values.where((d) => d.label != widget.fromLabel).toList();

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _setOpen(bool next) {
    if (_open == next) return;
    setState(() => _open = next);
  }

  void _toggle(BeuiDayKey k) {
    setState(() {
      if (!_picked.add(k)) _picked.remove(k);
    });
  }

  void _apply(List<BeuiDayKey> targets) {
    if (targets.isEmpty) return;
    widget.onApply(targets);
    _copiedTimer?.cancel();
    setState(() {
      _open = false;
      _picked.clear();
      _copied = true;
    });
    _copiedTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return BeuiOverlay(
      open: _open,
      onDismiss: () => _setOpen(false),
      barrierColor: const Color(0x00000000),
      enterDuration: const Duration(milliseconds: 220),
      exitDuration: const Duration(milliseconds: 140),
      overlayBuilder: (context, animation, link) =>
          _buildPanel(context, animation, link, colors, reduce),
      child: BeuiTooltip(
        content: const Text('Copy times'),
        child: SchedulerIconButton(
          label: 'Copy ${widget.fromLabel} hours to other days',
          expanded: _open,
          onPressed: () => _setOpen(!_open),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: beuiEaseOut,
            switchOutCurve: beuiEaseOut,
            transitionBuilder: (child, anim) {
              final fade = FadeTransition(opacity: anim, child: child);
              if (reduce) return fade;
              // Source: scale 0.5 → 1 on SPRING_PRESS; approximated with the
              // switcher's EASE_OUT curve for this single-glyph swap.
              return ScaleTransition(
                scale: Tween<double>(begin: 0.5, end: 1).animate(anim),
                child: fade,
              );
            },
            child: _copied
                ? const Icon(LucideIcons.check, key: ValueKey('done'))
                : const Icon(LucideIcons.copy, key: ValueKey('copy')),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
    BeuiColors colors,
    bool reduce,
  ) {
    final others = _others;

    final panel = Material(
      type: MaterialType.transparency,
      child: Container(
        width: 208, // w-52
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.popover,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                'Copy times to',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.mutedForeground,
                ),
              ),
            ),
            for (final d in others)
              _DayCheck(
                label: d.label,
                checked: _picked.contains(d),
                colors: colors,
                onToggle: () => _toggle(d),
              ),
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FooterButton(
                      label: 'Every day',
                      colors: colors,
                      onTap: () => _apply(others),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FooterButton(
                      label: 'Apply',
                      colors: colors,
                      primary: true,
                      enabled: _picked.isNotEmpty,
                      onTap: () => _apply(_picked.toList()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 6),
      child: Align(
        alignment: Alignment.topRight,
        child: AnimatedBuilder(
          animation: animation,
          child: panel,
          builder: (context, child) {
            final t = animation.value.clamp(0.0, 1.0);
            if (reduce) return Opacity(opacity: t, child: child);
            return Opacity(
              opacity: t,
              child: SingleMotionBuilder(
                value: 1,
                from: 0,
                motion: beuiSpringPanel,
                child: child,
                builder: (context, s, inner) => Transform.translate(
                  offset: Offset(0, -6 * (1 - s)),
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * s,
                    alignment: Alignment.topRight,
                    child: inner,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One day row in the picker: label on the left, checkbox on the right (source
/// `flex-row-reverse`), with a hover fill.
class _DayCheck extends StatefulWidget {
  const _DayCheck({
    required this.label,
    required this.checked,
    required this.colors,
    required this.onToggle,
  });

  final String label;
  final bool checked;
  final BeuiColors colors;
  final VoidCallback onToggle;

  @override
  State<_DayCheck> createState() => _DayCheckState();
}

class _DayCheckState extends State<_DayCheck> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? colors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(fontSize: 14, color: colors.foreground),
                ),
              ),
              IgnorePointer(
                child: BeuiCheckbox(
                  value: widget.checked,
                  onChanged: (_) {},
                  style: const BeuiCheckboxStyle(size: 16, borderRadius: 5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A footer button ("Every day" / "Apply").
class _FooterButton extends StatefulWidget {
  const _FooterButton({
    required this.label,
    required this.colors,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final BeuiColors colors;
  final VoidCallback onTap;
  final bool primary;
  final bool enabled;

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final enabled = widget.enabled;

    final Color bg;
    final Color fg;
    if (widget.primary) {
      bg = colors.primary;
      fg = colors.primaryForeground;
    } else {
      bg = _hovered ? colors.muted : Colors.transparent;
      fg = _hovered ? colors.foreground : colors.mutedForeground;
    }

    return Opacity(
      opacity: enabled ? (widget.primary && _hovered ? 0.9 : 1.0) : 0.4,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        child: MouseRegion(
          cursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? widget.onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.ease,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.primary
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
