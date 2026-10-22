import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'action_swap.dart';

/// One possible outcome in a [BeuiPredictionMarketCard].
@immutable
class BeuiPredictionMarketCardOutcome {
  /// Creates an outcome with a probability in the inclusive range 0..1.
  const BeuiPredictionMarketCardOutcome({
    required this.id,
    required this.label,
    required this.probability,
    this.icon,
    this.color,
  });

  /// Stable identifier returned in [BeuiPredictionMarketCardSelection].
  final String id;

  /// Human-readable outcome label.
  final String label;

  /// Outcome probability, clamped to 0..1 when rendered.
  final double probability;

  /// Optional outcome artwork.
  final Widget? icon;

  /// Optional accent color for the probability indicator.
  final Color? color;
}

/// The side selected from an outcome row.
enum BeuiPredictionMarketCardSide { yes, no }

/// The outcome and side chosen from a market card.
@immutable
class BeuiPredictionMarketCardSelection {
  /// Creates a selection.
  const BeuiPredictionMarketCardSelection({
    required this.outcomeId,
    required this.side,
  });

  /// The selected outcome ID.
  final String outcomeId;

  /// Whether the user chose Yes or No.
  final BeuiPredictionMarketCardSide side;
}

/// Compact market listing with outcomes, trade odds, volume and bookmarking.
class BeuiPredictionMarketCard extends StatefulWidget {
  /// Creates a prediction market card.
  const BeuiPredictionMarketCard({
    required this.title,
    required this.volume,
    required this.outcomes,
    this.icon,
    this.category,
    this.volumeHistory,
    this.status,
    this.live = false,
    this.onOutcomeClick,
    this.bookmarked,
    this.defaultBookmarked = false,
    this.onBookmarkChange,
    super.key,
  });

  /// Market headline.
  final String title;

  /// Optional leading market artwork.
  final Widget? icon;

  /// Optional category displayed with the status.
  final String? category;

  /// Display-formatted market volume.
  final String volume;

  /// Optional chronological samples for the footer sparkline.
  final List<double>? volumeHistory;

  /// Scheduled time or current live status.
  final String? status;

  /// Whether [status] is currently live.
  final bool live;

  /// Available market outcomes.
  final List<BeuiPredictionMarketCardOutcome> outcomes;

  /// Called when a Yes or No CTA is selected.
  final ValueChanged<BeuiPredictionMarketCardSelection>? onOutcomeClick;

  /// Controlled bookmark state. When null, state is managed internally.
  final bool? bookmarked;

  /// Initial bookmark state in uncontrolled mode.
  final bool defaultBookmarked;

  /// Called when the bookmark is toggled.
  final ValueChanged<bool>? onBookmarkChange;

  @override
  State<BeuiPredictionMarketCard> createState() =>
      _BeuiPredictionMarketCardState();
}

class _BeuiPredictionMarketCardState extends State<BeuiPredictionMarketCard> {
  late bool _internalBookmark = widget.defaultBookmarked;

  bool get _bookmarked => widget.bookmarked ?? _internalBookmark;

  void _toggleBookmark() {
    final next = !_bookmarked;
    if (widget.bookmarked == null) setState(() => _internalBookmark = next);
    widget.onBookmarkChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: colors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                      alignment: Alignment.center,
                      child: widget.icon,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                          ),
                        ),
                        if (widget.status != null || widget.category != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                if (widget.status != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.live) ...[
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: colors.destructive,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        widget.status!,
                                        style: TextStyle(
                                          color: widget.live
                                              ? colors.destructive
                                              : colors.mutedForeground,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (widget.status != null &&
                                    widget.category != null)
                                  Text(
                                    '·',
                                    style: TextStyle(
                                      color: colors.mutedForeground,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (widget.category != null)
                                  Text(
                                    widget.category!,
                                    style: TextStyle(
                                      color: colors.mutedForeground,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.outcomes.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _OutcomeRow(
                        outcome: widget.outcomes[i],
                        index: i,
                        colors: colors,
                        onSelected: (side) => widget.onOutcomeClick?.call(
                          BeuiPredictionMarketCardSelection(
                            outcomeId: widget.outcomes[i].id,
                            side: side,
                          ),
                        ),
                      ),
                    ],
                    if (widget.volumeHistory != null &&
                        widget.volumeHistory!.length > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 48,
                            height: 22,
                            child: CustomPaint(
                              painter: _SparklinePainter(
                                widget.volumeHistory!,
                                colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.volume} vol.',
                            style: TextStyle(
                              color: colors.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          _BookmarkButton(
                            title: widget.title,
                            saved: _bookmarked,
                            colors: colors,
                            onPressed: _toggleBookmark,
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${widget.volume} vol.',
                            style: TextStyle(
                              color: colors.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          _BookmarkButton(
                            title: widget.title,
                            saved: _bookmarked,
                            colors: colors,
                            onPressed: _toggleBookmark,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.outcome,
    required this.index,
    required this.colors,
    required this.onSelected,
  });

  final BeuiPredictionMarketCardOutcome outcome;
  final int index;
  final BeuiColors colors;
  final ValueChanged<BeuiPredictionMarketCardSide> onSelected;

  @override
  Widget build(BuildContext context) {
    final probability = outcome.probability.isFinite
        ? outcome.probability.clamp(0.0, 1.0)
        : 0.0;
    final yes = index.isEven;
    final side = yes
        ? BeuiPredictionMarketCardSide.yes
        : BeuiPredictionMarketCardSide.no;
    final payout = probability <= 0
        ? '—'
        : '${(1 / probability).toStringAsFixed(1)}×';
    return Row(
      children: [
        if (outcome.icon != null) ...[
          ClipOval(
            child: SizedBox(
              width: 28,
              height: 28,
              child: ColoredBox(color: colors.muted, child: outcome.icon),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                outcome.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 76,
                height: 2,
                child: FractionallySizedBox(
                  widthFactor: probability,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: outcome.color ?? (yes ? _yesFill : _noFill),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          payout,
          style: TextStyle(
            color: colors.mutedForeground,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        _OddsButton(
          outcomeLabel: outcome.label,
          percent: (probability * 100).round(),
          side: side,
          accent: yes ? _yesFill : _noFill,
          labelColor: yes ? _yesLabel : _noLabel,
          onPressed: () => onSelected(side),
        ),
      ],
    );
  }
}

const _yesFill = Color(0xFF1B7A4A);
const _noFill = Color(0xFF8B3A4A);
const _yesLabel = Color(0xFFD4F5E2);
const _noLabel = Color(0xFFF5D0D6);

class _OddsButton extends StatefulWidget {
  const _OddsButton({
    required this.outcomeLabel,
    required this.percent,
    required this.side,
    required this.accent,
    required this.labelColor,
    required this.onPressed,
  });

  final String outcomeLabel;
  final int percent;
  final BeuiPredictionMarketCardSide side;
  final Color accent;
  final Color labelColor;
  final VoidCallback onPressed;

  @override
  State<_OddsButton> createState() => _OddsButtonState();
}

class _OddsButtonState extends State<_OddsButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final motion = motionFor(context, beuiSpringPress, isMovement: true);
    final active = _hovered || _focused;
    final action = widget.side == BeuiPredictionMarketCardSide.yes
        ? 'Yes'
        : 'No';
    final targetScale = _pressed && !reduce ? .96 : 1.0;
    final face = Semantics(
      button: true,
      label:
          'Trade ${widget.side.name} ${widget.outcomeLabel} at ${widget.percent}%',
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.accent.withValues(alpha: active ? 0.95 : 0.82),
          borderRadius: BorderRadius.circular(12),
        ),
        child: BeuiActionSwapText(
          value: active ? action : '${widget.percent}%',
          text: active ? action : '${widget.percent}%',
          variant: BeuiActionSwapVariant.roll,
          style: TextStyle(
            color: widget.labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final scaled = motion is NoMotion
        ? face
        : MotionBuilder<Size>(
            value: Size(targetScale, targetScale),
            from: const Size(1, 1),
            converter: const SizeMotionConverter(),
            motion: motion,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale.width, child: child),
            child: face,
          );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onHover: (hovered) => setState(() => _hovered = hovered),
        onFocusChange: (focused) => setState(() => _focused = focused),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        canRequestFocus: true,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: scaled,
      ),
    );
  }
}

class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton({
    required this.title,
    required this.saved,
    required this.colors,
    required this.onPressed,
  });

  final String title;
  final bool saved;
  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scale = _pressed && !reduce ? .85 : 1.0;
    final motion = motionFor(context, beuiSpringPress, isMovement: true);
    final face = Semantics(
      button: true,
      toggled: widget.saved,
      label: 'Bookmark ${widget.title}',
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          LucideIcons.bookmark,
          size: 17,
          color: widget.colors.foreground,
          fill: widget.saved ? 1 : 0,
        ),
      ),
    );
    final scaled = motion is NoMotion
        ? face
        : MotionBuilder<Size>(
            value: Size(scale, scale),
            from: const Size(1, 1),
            converter: const SizeMotionConverter(),
            motion: motion,
            builder: (context, value, child) =>
                Transform.scale(scale: value.width, child: child),
            child: face,
          );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        canRequestFocus: true,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: scaled,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.samples, this.color);

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final values = samples.where((sample) => sample.isFinite).toList();
    if (values.length < 2) return;
    final low = values.reduce(math.min);
    final range = values.reduce(math.max) - low;
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          1 + i / (values.length - 1) * (size.width - 2),
          size.height -
              2 -
              (range == 0 ? .5 : (values[i] - low) / range) * (size.height - 5),
        ),
    ];
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fill = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      fill.lineTo(point.dx, point.dy);
    }
    fill
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.color != color;
}
