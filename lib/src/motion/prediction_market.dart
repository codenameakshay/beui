import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_format.dart';
import '_shake.dart';
import 'button/base.dart';
import 'button/stateful.dart';
import 'number_ticker.dart';

/// Trade direction (source `PredictionMarketMode`).
enum BeuiPredictionMarketMode {
  /// Spend currency for shares.
  buy,

  /// Sell shares back.
  sell,
}

/// One tradable outcome (source `PredictionMarketOutcome`).
@immutable
class BeuiPredictionMarketOutcome {
  /// Creates an outcome.
  const BeuiPredictionMarketOutcome({
    required this.id,
    required this.label,
    required this.price,
  });

  /// Stable identity.
  final String id;

  /// Cell label ("Yes"/"No"/"Up"/"Down" get the red/green tinting).
  final String label;

  /// Price per share, 0..1.
  final double price;
}

/// The ticket's order state (source `PredictionMarketOrderValue`).
@immutable
class BeuiPredictionMarketOrder {
  /// Creates an order value.
  const BeuiPredictionMarketOrder({
    required this.mode,
    required this.outcomeId,
    required this.amount,
  });

  /// Trade direction.
  final BeuiPredictionMarketMode mode;

  /// Selected outcome id.
  final String outcomeId;

  /// Raw amount text (dollars when buying, shares when selling).
  final String amount;

  /// Copy with fields replaced.
  BeuiPredictionMarketOrder copyWith({
    BeuiPredictionMarketMode? mode,
    String? outcomeId,
    String? amount,
  }) => BeuiPredictionMarketOrder(
    mode: mode ?? this.mode,
    outcomeId: outcomeId ?? this.outcomeId,
    amount: amount ?? this.amount,
  );

  @override
  bool operator ==(Object other) =>
      other is BeuiPredictionMarketOrder &&
      other.mode == mode &&
      other.outcomeId == outcomeId &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(mode, outcomeId, amount);
}

/// Derived pricing for the current order (source `PredictionMarketQuote`).
@immutable
class BeuiPredictionMarketQuote {
  /// Creates a quote.
  const BeuiPredictionMarketQuote({
    required this.valid,
    required this.amount,
    required this.price,
    required this.shares,
    required this.payout,
    this.error,
  });

  /// Whether the order can be placed.
  final bool valid;

  /// Parsed amount.
  final double amount;

  /// Clamped share price (0.01–0.99).
  final double price;

  /// Shares bought/sold.
  final double shares;

  /// Winnings (buy) or proceeds (sell).
  final double payout;

  /// Why the order is invalid.
  final String? error;
}

enum _OrderStatus { idle, placing, filled }

String _sanitizeAmount(String value) {
  final normalized = value.replaceAll(RegExp(r'[^\d.]'), '');
  final parts = normalized.split('.');
  if (parts.length == 1) return parts.first;
  final decimal = parts.sublist(1).join();
  return '${parts.first}.${decimal.substring(0, math.min(2, decimal.length))}';
}

String _formatCurrency(double value, [int maxFractionDigits = 2]) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(maxFractionDigits);
  final parts = fixed.split('.');
  final grouped = beuiGroupThousands(parts.first);
  final tail = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}\$$grouped$tail';
}

String _formatCompactCurrency(double value) => value >= 100
    ? _formatCurrency(value, 0)
    : _formatCurrency(value, value % 1 == 0 ? 0 : 2);

String _formatCents(double value) {
  final cents = value * 100;
  final precision = cents == cents.roundToDouble() ? 0 : 1;
  return '${cents.toStringAsFixed(precision)}¢';
}

/// Digit roll timing (source `DIGIT_TRANSITION`, 180ms `EASE_OUT`).
const _digitMs = 180;

/// A prediction-market trade ticket: buy/sell modes, outcome prices, a
/// rolling amount entry, quote footer with a ticking payout, and a stateful
/// trade button — the Flutter port of beUI's `PredictionMarket` block,
/// composed from [BeuiStatefulButton] and [BeuiNumberTicker].
///
/// Demo-grade like the source: the quote is local math and "placing" resolves
/// after 650ms.
class BeuiPredictionMarket extends StatefulWidget {
  /// Creates a trade ticket.
  const BeuiPredictionMarket({
    this.outcomes = const [
      BeuiPredictionMarketOutcome(id: 'up', label: 'Up', price: 0.09),
      BeuiPredictionMarketOutcome(id: 'down', label: 'Down', price: 0.91),
    ],
    this.value,
    this.defaultMode = BeuiPredictionMarketMode.buy,
    this.defaultOutcomeId,
    this.defaultAmount = '',
    this.onValueChange,
    this.onTrade,
    this.onSignIn,
    this.authenticated = true,
    this.orderTypeLabel = 'Market',
    this.balance = 500,
    this.positions = const {'up': 24, 'down': 16},
    this.quickAmounts = const [10, 50, 100, 500],
    this.minTrade = 1,
    super.key,
  });

  /// The outcomes (two cells).
  final List<BeuiPredictionMarketOutcome> outcomes;

  /// Controlled order; null for uncontrolled.
  final BeuiPredictionMarketOrder? value;

  /// Initial mode when uncontrolled.
  final BeuiPredictionMarketMode defaultMode;

  /// Initial outcome when uncontrolled (defaults to the first).
  final String? defaultOutcomeId;

  /// Initial amount when uncontrolled.
  final String defaultAmount;

  /// Fires with the order the ticket wants.
  final ValueChanged<BeuiPredictionMarketOrder>? onValueChange;

  /// Fires when a valid trade fills.
  final void Function(
    BeuiPredictionMarketOrder order,
    BeuiPredictionMarketQuote quote,
  )?
  onTrade;

  /// Fires when the unauthenticated Connect button is pressed.
  final VoidCallback? onSignIn;

  /// Whether the trading footer is shown (source `authenticated`).
  final bool authenticated;

  /// Order-type dropdown label (decorative, like the source).
  final String orderTypeLabel;

  /// Spendable balance for buys.
  final double balance;

  /// Held shares per outcome id, spendable on sells.
  final Map<String, double> positions;

  /// Quick-add chip values.
  final List<double> quickAmounts;

  /// Minimum buy (source `minTrade = 1`).
  final double minTrade;

  @override
  State<BeuiPredictionMarket> createState() => _BeuiPredictionMarketState();
}

class _BeuiPredictionMarketState extends State<BeuiPredictionMarket>
    with SingleTickerProviderStateMixin {
  late BeuiPredictionMarketOrder _internal = BeuiPredictionMarketOrder(
    mode: widget.defaultMode,
    outcomeId: widget.defaultOutcomeId ?? widget.outcomes.first.id,
    amount: widget.defaultAmount,
  );
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode(debugLabel: 'BeuiPredictionMarket');
  _OrderStatus _status = _OrderStatus.idle;
  Timer? _fillTimer;
  late final AnimationController _shake;

  BeuiPredictionMarketOrder get _order => widget.value ?? _internal;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _input.text = _order.amount;
  }

  @override
  void dispose() {
    _fillTimer?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _setOrder(BeuiPredictionMarketOrder next) {
    _fillTimer?.cancel();
    _fillTimer = null;
    if (_status != _OrderStatus.idle) _status = _OrderStatus.idle;
    if (widget.value == null) {
      setState(() => _internal = next);
    } else {
      setState(() {});
    }
    if (_input.text != next.amount) {
      _input.value = TextEditingValue(
        text: next.amount,
        selection: TextSelection.collapsed(offset: next.amount.length),
      );
    }
    widget.onValueChange?.call(next);
  }

  BeuiPredictionMarketOutcome get _selected =>
      widget.outcomes.where((o) => o.id == _order.outcomeId).firstOrNull ??
      widget.outcomes.first;

  BeuiPredictionMarketQuote get _quote {
    final order = _order;
    final amount = double.tryParse(order.amount) ?? 0;
    final price = _selected.price.clamp(0.01, 0.99);
    final buy = order.mode == BeuiPredictionMarketMode.buy;
    final shares = buy ? amount / price : amount;
    final payout = buy ? shares : amount * price;
    final position = widget.positions[_selected.id] ?? 0;

    String? error;
    if (amount <= 0) {
      error = 'Enter an amount';
    } else if (buy && amount < widget.minTrade) {
      error = 'Minimum ${_formatCompactCurrency(widget.minTrade)}';
    } else if (buy && amount > widget.balance) {
      error = 'Insufficient balance';
    } else if (!buy && amount > position) {
      error = 'Not enough shares';
    }
    return BeuiPredictionMarketQuote(
      valid: error == null,
      amount: amount,
      price: price,
      shares: amount <= 0 ? 0 : shares,
      payout: amount <= 0 ? 0 : payout,
      error: error,
    );
  }

  void _submit() {
    if (!widget.authenticated) {
      widget.onSignIn?.call();
      return;
    }
    final quote = _quote;
    if (!quote.valid) {
      if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
      setState(() {}); // surface the error state on the button
      return;
    }
    setState(() => _status = _OrderStatus.placing);
    _fillTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _status = _OrderStatus.filled);
      widget.onTrade?.call(_order, quote);
    });
  }

  // Shake keyframes (source `x: [0,-5,5,-3,3,-1,0]`, 380ms EASE_OUT, eased
  // globally then interpolated linearly between frames).
  static const _shakeFrames = [0.0, -5.0, 5.0, -3.0, 3.0, -1.0, 0.0];

  double _shakeX(double t) =>
      beuiShakeOffset(t, _shakeFrames, beuiEaseOut, perSegment: false);

  /// Source `amountInputSize`. Each rung carries an `sm:` step that doubles as
  /// the desktop size, so the ticket reads far larger at/above the 640px
  /// breakpoint than the mobile base — the port previously used the base sizes
  /// everywhere and rendered the amount ~20% too small on desktop.
  double _amountFontSize(String amount, bool wide) {
    final length = amount.replaceAll(RegExp(r'\D'), '').length;
    if (length >= 10) return wide ? 36 : 30; // text-3xl sm:text-4xl
    if (length >= 8) return wide ? 48 : 36; // text-4xl sm:text-5xl
    if (length >= 6) return wide ? 56 : 44; // text-[44px] sm:text-[56px]
    return wide ? 60 : 48; // text-5xl sm:text-6xl
  }

  /// Source `payoutTickerSize`. Only the longest rung has an `sm:` step.
  double _payoutFontSize(double payout, bool wide) {
    final length = _formatCurrency(payout).length;
    if (length >= 16) return wide ? 24 : 20; // text-xl sm:text-2xl
    if (length >= 13) return 24; // text-2xl
    if (length >= 10) return 30; // text-3xl
    return 36; // text-4xl
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    // Tailwind `sm:` keys off the viewport, not the element box (the ticket is
    // capped at 400px yet still takes the `sm:` type scale on desktop).
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final order = _order;
    final quote = _quote;
    final buy = order.mode == BeuiPredictionMarketMode.buy;
    final placing = _status == _OrderStatus.placing;

    final actionState = _status == _OrderStatus.placing
        ? BeuiButtonState.loading
        : _status == _OrderStatus.filled
        ? BeuiButtonState.success
        : quote.valid
        ? BeuiButtonState.idle
        : BeuiButtonState.error;

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(24), // rounded-3xl
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Buy/Sell underline tabs + order-type label.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: colors.border.a * 0.8),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ModeTabs(
                  mode: order.mode,
                  reduce: reduce,
                  colors: colors,
                  onChanged: (mode) =>
                      _setOrder(order.copyWith(mode: mode, amount: '')),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Opacity(
                    opacity: placing ? 0.5 : 1,
                    child: Row(
                      spacing: 8,
                      children: [
                        Text(
                          widget.orderTypeLabel,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colors.foreground,
                          ),
                        ),
                        Icon(
                          LucideIcons.chevron_down,
                          size: 20,
                          color: colors.foreground,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12), // p-3
            child: Column(
              spacing: 16, // space-y-4
              children: [
                // Outcome cells: a single shared-layout pill glides between the
                // selected cells (source `Tabs variant="pill"`).
                _OutcomeCells(
                  outcomes: widget.outcomes,
                  selectedId: _selected.id,
                  reduce: reduce,
                  colors: colors,
                  onTap: (outcome) =>
                      _setOrder(order.copyWith(outcomeId: outcome.id)),
                ),
                // Amount card (shakes on invalid submit).
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    final x = _shake.isAnimating ? _shakeX(_shake.value) : 0.0;
                    return x == 0
                        ? child!
                        : Transform.translate(
                            offset: Offset(x, 0),
                            child: child,
                          );
                  },
                  child: _AmountCard(
                    order: order,
                    controller: _input,
                    focusNode: _inputFocus,
                    fontSize: _amountFontSize(order.amount, wide),
                    disabled: placing,
                    reduce: reduce,
                    colors: colors,
                    onChanged: (v) {
                      final sanitized = _sanitizeAmount(v);
                      if (sanitized != v) {
                        _input.value = TextEditingValue(
                          text: sanitized,
                          selection: TextSelection.collapsed(
                            offset: sanitized.length,
                          ),
                        );
                      }
                      _setOrder(order.copyWith(amount: sanitized));
                    },
                    quickAmounts: widget.quickAmounts,
                    onQuickAdd: (add) {
                      final next = (double.tryParse(order.amount) ?? 0) + add;
                      _setOrder(order.copyWith(amount: _trimNumber(next)));
                    },
                    onMax: () {
                      if (buy) {
                        _setOrder(
                          order.copyWith(
                            amount: widget.balance.floor().toString(),
                          ),
                        );
                      } else {
                        final position = widget.positions[_selected.id] ?? 0;
                        _setOrder(
                          order.copyWith(amount: _trimNumber(position)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.authenticated)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.border.withValues(
                      alpha: colors.border.a * 0.8,
                    ),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    // `justify-between` + the payout's `ml-auto`: the label
                    // block hugs the left edge, the payout the right.
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                spacing: 8,
                                children: [
                                  Text(
                                    buy ? 'To win' : 'To receive',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: colors.foreground,
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.banknote,
                                    size: 20,
                                    color: Color(0xFF10B981), // emerald-500
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Avg. Price ${_formatCents(quote.price)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Payout ticks in cents behind a currency format
                      // (source NumberTicker value*100 + format); scales
                      // down rather than overflowing (source min-w-0).
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: BeuiNumberTicker(
                            value: quote.payout * 100,
                            duration: const Duration(milliseconds: 450),
                            stagger: Duration.zero,
                            blur: true,
                            // The payout lives inside the card, not a feed —
                            // roll immediately (source `startOnView={false}`).
                            startOnView: false,
                            format: (cents) => _formatCurrency(cents / 100),
                            style: TextStyle(
                              fontSize: _payoutFontSize(quote.payout, wide),
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: BeuiStatefulButton(
                      label: 'Trade',
                      state: actionState,
                      size: BeuiButtonSize.lg,
                      loadingText: 'Trading',
                      successText: 'Trade filled',
                      errorText: quote.error ?? 'Enter an amount',
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity,
                // Source Connect button is `h-14` (56px), not the `lg` default
                // (48px). The outer tight height enforces down onto BeuiButton's
                // internal fixed-height box, so the surface renders at 56px.
                height: 56,
                child: BeuiStatefulButton(
                  label: 'Connect',
                  size: BeuiButtonSize.lg,
                  onPressed: _submit,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _trimNumber(double n) {
  if (n == n.roundToDouble()) return n.round().toString();
  return n
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

/// Buy/Sell as 24px underline tabs; the 2px underline glides between labels
/// on the shared layout spring (source Tabs `variant="underline"`).
class _ModeTabs extends StatefulWidget {
  const _ModeTabs({
    required this.mode,
    required this.reduce,
    required this.colors,
    required this.onChanged,
  });

  final BeuiPredictionMarketMode mode;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<BeuiPredictionMarketMode> onChanged;

  @override
  State<_ModeTabs> createState() => _ModeTabsState();
}

class _ModeTabsState extends State<_ModeTabs> {
  final Map<BeuiPredictionMarketMode, GlobalKey> _keys = {
    BeuiPredictionMarketMode.buy: GlobalKey(),
    BeuiPredictionMarketMode.sell: GlobalKey(),
  };
  final GlobalKey _rowKey = GlobalKey();
  Rect? _indicator;

  void _measure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final label =
          _keys[widget.mode]!.currentContext?.findRenderObject() as RenderBox?;
      final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
      if (label == null || row == null) return;
      final rect = label.localToGlobal(Offset.zero, ancestor: row) & label.size;
      if (rect != _indicator) setState(() => _indicator = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    final colors = widget.colors;
    return Stack(
      key: _rowKey,
      clipBehavior: Clip.none,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 20, // gap-5
          children: [
            for (final mode in BeuiPredictionMarketMode.values)
              Semantics(
                button: true,
                selected: mode == widget.mode,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onChanged(mode),
                    child: Padding(
                      key: _keys[mode],
                      padding: const EdgeInsets.only(bottom: 12), // pb-3
                      child: Text(
                        mode == BeuiPredictionMarketMode.buy ? 'Buy' : 'Sell',
                        style: TextStyle(
                          fontSize: 24, // text-2xl
                          fontWeight: FontWeight.w600,
                          color: mode == widget.mode
                              ? colors.foreground
                              : colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_indicator != null)
          MotionBuilder<Rect>(
            value: _indicator!,
            motion: widget.reduce ? const NoMotion() : beuiSpringLayout,
            converter: const RectMotionConverter(),
            builder: (context, rect, _) {
              final r = widget.reduce ? _indicator! : rect;
              return Positioned(
                left: r.left,
                width: r.width,
                bottom: 0,
                height: 2, // h-0.5 bg-foreground
                child: ColoredBox(color: colors.foreground),
              );
            },
          ),
      ],
    );
  }
}

bool _isNoOutcome(String label) {
  final l = label.toLowerCase();
  return l == 'no' || l == 'down';
}

/// Glide spring for the outcome pill. The source renders the two outcome cells
/// via `Tabs variant="pill"`, whose shared-layout indicator rides the Tabs
/// `transition` spring (stiffness 170 · damping 24 · mass 1.2 — `tabs.tsx`),
/// **not** `SPRING_LAYOUT`. This mirrors [BeuiTabs]' component-local
/// `_indicatorSpring` verbatim so the outcome pill moves identically to every
/// other pill in the library.
const _outcomePillSpring = SpringMotion(
  SpringDescription(mass: 1.2, stiffness: 170, damping: 24),
);

/// The two outcome cells with a single shared-layout pill that glides between
/// the selected cell's rect on [_outcomePillSpring] — the Flutter analog of the
/// source's `Tabs variant="pill"` (`layoutId` indicator). The pill takes the
/// selected outcome's tint (red for No/Down, emerald otherwise) and is fully
/// rounded (source `borderRadius: 9999`). Under reduced motion it snaps.
class _OutcomeCells extends StatefulWidget {
  const _OutcomeCells({
    required this.outcomes,
    required this.selectedId,
    required this.reduce,
    required this.colors,
    required this.onTap,
  });

  final List<BeuiPredictionMarketOutcome> outcomes;
  final String selectedId;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<BeuiPredictionMarketOutcome> onTap;

  @override
  State<_OutcomeCells> createState() => _OutcomeCellsState();
}

class _OutcomeCellsState extends State<_OutcomeCells> {
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _keys = {};
  Rect? _pill;

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  void _measure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cell =
          _keys[widget.selectedId]?.currentContext?.findRenderObject()
              as RenderBox?;
      final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (cell == null || stack == null || !cell.hasSize) return;
      final rect = cell.localToGlobal(Offset.zero, ancestor: stack) & cell.size;
      if (rect != _pill) setState(() => _pill = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    final colors = widget.colors;

    // Pill tint = the selected outcome's cell colour (source per-trigger
    // `indicatorClassName`): red-500/… for No/Down, else emerald-500/20.
    final selected =
        widget.outcomes.where((o) => o.id == widget.selectedId).firstOrNull ??
        widget.outcomes.first;
    final pillColor = _isNoOutcome(selected.label)
        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
        : const Color(0xFF10B981).withValues(alpha: 0.2);

    // The source `TabsList` keeps its `pill` variant's `rounded-full bg-card`
    // track and only overrides the layout classes, so the two cells sit inside
    // a card-tinted stadium with `p-1.5` around them. Without it the pill's
    // `bg-emerald-500/20` also composited over the page background instead of
    // the track, reading several steps too dark.
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(999), // rounded-full
      ),
      padding: const EdgeInsets.all(6), // p-1.5
      child: Stack(
        key: _stackKey,
        children: [
          if (_pill != null)
            MotionBuilder<Rect>(
              value: _pill!,
              motion: widget.reduce ? const NoMotion() : _outcomePillSpring,
              converter: const RectMotionConverter(),
              builder: (context, rect, _) {
                final r = widget.reduce ? _pill! : rect;
                return Positioned.fromRect(
                  rect: r,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      // Stable handle so motion tests can read the pill's bounds.
                      key: const ValueKey<String>(
                        'beui_prediction_market_pill',
                      ),
                      decoration: BoxDecoration(
                        color: pillColor,
                        borderRadius: BorderRadius.circular(r.height / 2),
                      ),
                    ),
                  ),
                );
              },
            ),
          Row(
            spacing: 8, // gap-2
            children: [
              for (final outcome in widget.outcomes)
                Expanded(
                  child: _OutcomeLabel(
                    key: _keyFor(outcome.id),
                    outcome: outcome,
                    selected: outcome.id == widget.selectedId,
                    colors: colors,
                    onTap: () => widget.onTap(outcome),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One outcome cell: the tappable label. The selected background is drawn by the
/// shared gliding pill in [_OutcomeCells], so the cell itself is transparent.
class _OutcomeLabel extends StatelessWidget {
  const _OutcomeLabel({
    required this.outcome,
    required this.selected,
    required this.colors,
    required this.onTap,
    super.key,
  });

  final BeuiPredictionMarketOutcome outcome;
  final bool selected;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNo = _isNoOutcome(outcome.label);
    const emerald = Color(0xFF34D399); // emerald-400
    const red = Color(0xFFFCA5A5); // red-300
    // `text-red-300/55 dark:text-red-300/50` when unselected.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isNo
        ? (selected ? red : red.withValues(alpha: dark ? 0.50 : 0.55))
        : (selected ? emerald : colors.mutedForeground);

    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 56, // h-14
            child: Center(
              child: Text(
                '${outcome.label} ${_formatCents(outcome.price)}',
                style: TextStyle(
                  fontSize: 16, // text-base
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.order,
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    required this.disabled,
    required this.reduce,
    required this.colors,
    required this.onChanged,
    required this.quickAmounts,
    required this.onQuickAdd,
    required this.onMax,
  });

  final BeuiPredictionMarketOrder order;
  final TextEditingController controller;
  final FocusNode focusNode;
  final double fontSize;
  final bool disabled;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<String> onChanged;
  final List<double> quickAmounts;
  final ValueChanged<double> onQuickAdd;
  final VoidCallback onMax;

  @override
  Widget build(BuildContext context) {
    final buy = order.mode == BeuiPredictionMarketMode.buy;

    Widget chip(String label, VoidCallback onTap) => Semantics(
      button: true,
      enabled: !disabled,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: Container(
            height: 36, // h-9
            padding: const EdgeInsets.symmetric(horizontal: 14), // px-3.5
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(12), // rounded-xl
            ),
            // `widthFactor: 1` keeps the chip hugging its label. A bare
            // `alignment:` on the Container would let it expand to the Wrap's
            // full width, stacking the chips one per line.
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            buy ? 'Amount' : 'Shares',
            style: TextStyle(
              fontSize: 20, // text-xl
              height: 28 / 20, // …/28
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 20),
          // Tap anywhere on the number to focus the hidden input.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: disabled ? null : focusNode.requestFocus,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (buy)
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.mutedForeground.withValues(alpha: 0.65),
                        ),
                        child: const Text('\$'),
                      ),
                    _AnimatedAmount(
                      value: controller.text.isEmpty ? '0' : controller.text,
                      placeholder: controller.text.isEmpty,
                      fontSize: fontSize,
                      reduce: reduce,
                      colors: colors,
                    ),
                  ],
                ),
                // The transparent input owns editing.
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: 0,
                      child: EditableText(
                        controller: controller,
                        focusNode: focusNode,
                        readOnly: disabled,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(color: Colors.transparent),
                        cursorColor: Colors.transparent,
                        backgroundCursorColor: Colors.transparent,
                        onChanged: onChanged,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32), // mt-8
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final amount in quickAmounts)
                chip(
                  '+${buy ? _formatCompactCurrency(amount) : _trimNumber(amount)}',
                  () => onQuickAdd(amount),
                ),
              chip('Max', onMax),
            ],
          ),
        ],
      ),
    );
  }
}

/// The giant amount readout: chars keyed by `char-occurrence` roll in from
/// below (y 18, blur 10) and out upward (y -14), 180ms `EASE_OUT`, popLayout
/// (source `AnimatedAmountInput`).
class _AnimatedAmount extends StatefulWidget {
  const _AnimatedAmount({
    required this.value,
    required this.placeholder,
    required this.fontSize,
    required this.reduce,
    required this.colors,
  });

  final String value;
  final bool placeholder;
  final double fontSize;
  final bool reduce;
  final BeuiColors colors;

  @override
  State<_AnimatedAmount> createState() => _AnimatedAmountState();
}

class _CharEntry {
  _CharEntry(this.id, this.char);

  final String id;
  final String char;
  bool exiting = false;
}

class _AnimatedAmountState extends State<_AnimatedAmount> {
  final List<_CharEntry> _entries = [];

  static List<(String, String)> _keyed(String value) {
    final seen = <String, int>{};
    return value.split('').map((char) {
      final count = seen[char] ?? 0;
      seen[char] = count + 1;
      return ('$char-$count', char);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    for (final (id, char) in _keyed(widget.value)) {
      _entries.add(_CharEntry(id, char));
    }
  }

  @override
  void didUpdateWidget(_AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final next = _keyed(widget.value);
    final nextIds = {for (final (id, _) in next) id};
    final known = {for (final e in _entries) e.id};
    for (final entry in _entries) {
      entry.exiting = !nextIds.contains(entry.id);
    }
    for (final (id, char) in next) {
      if (!known.contains(id)) _entries.add(_CharEntry(id, char));
    }
    // Keep display order: live entries sorted by their position in `next`.
    final orderOf = {for (var i = 0; i < next.length; i++) next[i].$1: i};
    _entries.sort(
      (a, b) => (orderOf[a.id] ?? 1 << 20).compareTo(orderOf[b.id] ?? 1 << 20),
    );
  }

  void _remove(_CharEntry entry) {
    if (!mounted) return;
    setState(() => _entries.remove(entry));
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w600,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: widget.placeholder
          ? widget.colors.mutedForeground.withValues(alpha: 0.55)
          : widget.colors.foreground,
    );
    return ClipRect(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _entries)
            _CharSlot(
              key: ValueKey(entry.id),
              char: entry.char,
              exiting: entry.exiting,
              reduce: widget.reduce,
              style: style,
              onExited: () => _remove(entry),
            ),
        ],
      ),
    );
  }
}

class _CharSlot extends StatelessWidget {
  const _CharSlot({
    required this.char,
    required this.exiting,
    required this.reduce,
    required this.style,
    required this.onExited,
    super.key,
  });

  final String char;
  final bool exiting;
  final bool reduce;
  final TextStyle style;
  final VoidCallback onExited;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: exiting ? 0.0 : 1.0,
      from: 0.0,
      motion: const CurvedMotion(Duration(milliseconds: _digitMs), beuiEaseOut),
      onAnimationStatusChanged: (status) {
        if (exiting &&
            (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed)) {
          onExited();
        }
      },
      builder: (context, raw, child) {
        final t = raw.clamp(0.0, 1.0);
        Widget body = child!;
        if (!reduce) {
          final sigma = beuiBlurSigma(10) * (1 - t);
          if (sigma > 0.05) {
            body = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: body,
            );
          }
          final dy = exiting ? -14.0 * (1 - t) : 18.0 * (1 - t);
          body = Transform.translate(offset: Offset(0, dy), child: body);
        }
        // Exiting chars leave layout width immediately-ish so neighbors
        // reflow (popLayout): collapse width with the fade.
        return ClipRect(
          child: Align(
            widthFactor: exiting ? t : 1,
            child: Opacity(opacity: t, child: body),
          ),
        );
      },
      child: Text(char, style: style),
    );
  }
}
