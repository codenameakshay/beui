import 'package:flutter/material.dart';

import '../../overlay/beui_overlay.dart';
import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';
import 'types.dart';

/// Row height of one option in the dropdown list — `py-1.5 text-sm`
/// (6 + 20 + 6).
const double _optionExtent = 32;

/// `max-h-56` (14rem) — the panel caps its height and scrolls the 48 options
/// instead of unfolding them all (source `time-select.tsx`).
const double _panelMaxHeight = 224;

/// A time field — the Flutter port of the scheduler's `time-select.tsx`.
///
/// The source composes the library `Select`; this port has no `BeuiSelect`, so
/// it builds an equivalent anchored dropdown on the shared [BeuiOverlay]
/// foundation (root overlay, Esc / tap-outside dismiss, focus trap). The trigger
/// reads like an input field showing the current value's 12-hour label in
/// tabular figures; opening springs a capped, scrollable option panel out just
/// below it on `SPRING_PANEL` ([beuiSpringPanel]) — the overlay-panel entrance
/// token — scrolling the selected option into view.
///
/// Reduced motion drops the scale/offset and fades the panel in on opacity only.
///
/// Internal to the scheduler — not part of the public surface.
class TimeSelect extends StatefulWidget {
  /// Creates a time select.
  const TimeSelect({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  /// Current `"HH:mm"` value.
  final String value;

  /// Selectable options.
  final List<BeuiTimeOption> options;

  /// Called with the chosen option's value.
  final ValueChanged<String> onChanged;

  @override
  State<TimeSelect> createState() => _TimeSelectState();
}

class _TimeSelectState extends State<TimeSelect> {
  bool _open = false;

  void _setOpen(bool next) {
    if (_open == next) return;
    setState(() => _open = next);
  }

  String get _label {
    for (final o in widget.options) {
      if (o.value == widget.value) return o.label;
    }
    return label12(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    return BeuiOverlay(
      open: _open,
      onDismiss: () => _setOpen(false),
      barrierColor: const Color(0x00000000), // invisible; outside tap closes
      enterDuration: const Duration(milliseconds: 220),
      exitDuration: const Duration(milliseconds: 140),
      overlayBuilder: _buildPanel,
      child: _Trigger(
        label: _label,
        open: _open,
        colors: colors,
        onTap: () => _setOpen(!_open),
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Animation<double> animation,
    LayerLink link,
  ) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final width = link.leaderSize?.width ?? 132;
    final selectedIndex = widget.options.indexWhere(
      (o) => o.value == widget.value,
    );
    final controller = ScrollController(
      initialScrollOffset: selectedIndex <= 0
          ? 0
          : (selectedIndex * _optionExtent -
                    _panelMaxHeight / 2 +
                    _optionExtent / 2)
                .clamp(0.0, double.infinity),
    );

    final panel = Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: _panelMaxHeight),
        decoration: BoxDecoration(
          // Source panel is `bg-background`, not the popover surface.
          color: colors.background,
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
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          controller: controller,
          padding: const EdgeInsets.all(4),
          itemExtent: _optionExtent,
          itemCount: widget.options.length,
          itemBuilder: (context, i) {
            final o = widget.options[i];
            return _Option(
              option: o,
              selected: o.value == widget.value,
              colors: colors,
              onTap: () {
                widget.onChanged(o.value);
                _setOpen(false);
              },
            );
          },
        ),
      ),
    );

    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      // Source opens an 8px gap between trigger and panel (`nearGap = 8`).
      offset: const Offset(0, 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedBuilder(
          animation: animation,
          child: panel,
          builder: (context, child) {
            final t = animation.value.clamp(0.0, 1.0);
            if (reduce) {
              // Opacity only under reduced motion.
              return Opacity(opacity: t, child: child);
            }
            // Scale/offset ride SPRING_PANEL; opacity tracks the same clock.
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
                    alignment: Alignment.topCenter,
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

/// The field trigger — an input-styled button showing the current label.
class _Trigger extends StatefulWidget {
  const _Trigger({
    required this.label,
    required this.open,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool open;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final borderColor = widget.open
        ? colors.ring
        : (_hovered ? colors.borderStrong : colors.input);

    return Semantics(
      button: true,
      expanded: widget.open,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.ease,
            // `px-3 py-2 text-sm` + 1px border: 12+12 wide, 8+20+8+2 = 38 tall.
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(12), // rounded-xl
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 14, // text-sm
                      height: 20 / 14, // …/20
                      color: colors.foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8), // gap-2
                Icon(
                  LucideIcons.chevron_down,
                  size: 16, // h-4 w-4
                  color: colors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One option row in the dropdown.
class _Option extends StatefulWidget {
  const _Option({
    required this.option,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final BeuiTimeOption option;
  final bool selected;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final highlight = _hovered || widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10), // px-2.5
          decoration: BoxDecoration(
            color: highlight ? colors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(8), // rounded-lg
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.option.label,
                  style: TextStyle(
                    fontSize: 14, // text-sm
                    height: 20 / 14,
                    // `text-muted-foreground`, going `text-foreground` when
                    // selected or hovered (source `SelectItem`).
                    color: highlight
                        ? colors.foreground
                        : colors.mutedForeground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (widget.selected)
                Icon(LucideIcons.check, size: 14, color: colors.foreground),
            ],
          ),
        ),
      ),
    );
  }
}
