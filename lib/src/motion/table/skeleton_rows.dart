part of 'table.dart';

/// A single pulsing placeholder row — the Flutter port of `skeleton-rows.tsx`.
///
/// Each cell holds a muted pill (`w-2/3`, or `w-10` right-aligned) that pulses
/// its opacity, the port of Tailwind's `animate-pulse` (a ~1.5s ease-in-out
/// opacity cycle, opacity kept — never movement). Under reduced motion the pulse
/// stops and the pill sits at a steady mid opacity.
class _SkeletonRow<T> extends StatefulWidget {
  const _SkeletonRow({
    required this.columns,
    required this.resolved,
    required this.colors,
    required this.reduce,
    required this.rowHeight,
    required this.selectable,
  });

  final List<BeuiTableColumn<T>> columns;
  final Map<String, double> resolved;
  final BeuiColors colors;
  final bool reduce;
  final double rowHeight;
  final bool selectable;

  @override
  State<_SkeletonRow<T>> createState() => _SkeletonRowState<T>();
}

class _SkeletonRowState<T> extends State<_SkeletonRow<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduce) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_SkeletonRow<T> old) {
    super.didUpdateWidget(old);
    if (widget.reduce && _pulse.isAnimating) {
      _pulse.stop();
    } else if (!widget.reduce && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final colors = w.colors;

    Widget bar(BeuiTableColumn<T> column) {
      final right = column.align == BeuiTableAlign.right;
      return Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: right ? null : 0.66,
          child: SizedBox(
            width: right ? 40 : null,
            height: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      );
    }

    Widget row = Row(
      children: [
        if (w.selectable) const SizedBox(width: _checkboxWidth),
        for (final column in w.columns)
          SizedBox(
            width: w.resolved[column.key],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: bar(column),
            ),
          ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );

    row = Container(
      height: w.rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: row,
    );

    if (w.reduce) return Opacity(opacity: 0.6, child: row);

    // animate-pulse: opacity 1 → 0.5 → 1, ease-in-out.
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Opacity(opacity: 1 - 0.5 * t, child: child);
      },
      child: row,
    );
  }
}
