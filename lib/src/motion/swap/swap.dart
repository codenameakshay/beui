import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';
import 'data.dart';
import 'models.dart';
import 'token_picker.dart';

export 'data.dart';
export 'models.dart';

/// Flip-arrow spring (source 380 · 26 · 0.6).
const _flipSpring = SpringMotion(
  SpringDescription(mass: 0.6, stiffness: 380, damping: 26),
);

String sanitizeAmount(String v) {
  final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
  final parts = cleaned.split('.');
  if (parts.length <= 1) return cleaned;
  return '${parts.first}.${parts.sublist(1).join()}';
}

/// The raw, ungrouped numeric string for [n] — mirrors JS `String(number)`:
/// whole numbers drop the trailing `.0` (`4521.0` → "4521"), fractions keep
/// their digits (`1.245` → "1.245"). Unlike [formatAmount] it never inserts
/// thousands separators, so the result stays parseable by [double.tryParse].
/// Used by the MAX affordance the same way source `field.tsx` uses
/// `String(token.balance)`.
String rawAmount(double n) {
  if (!n.isFinite) return '0';
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toString();
}

String formatAmount(double n, [int max = 6]) {
  if (!n.isFinite || n == 0) return '0';
  String trim(String s) => s.contains('.')
      ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : s;
  if (n >= 1000) {
    final fixed = trim(n.toStringAsFixed(2));
    final parts = fixed.split('.');
    final digits = parts.first;
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped.toString();
  }
  return trim(n.toStringAsFixed(max));
}

bool isValidAddress(String v) {
  if (RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(v)) return true;
  if (RegExp(r'\.(eth|sol|bnb)$').hasMatch(v) && v.length > 5) return true;
  return false;
}

String truncateAddress(String v) {
  if (v.startsWith('0x') && v.length == 42) {
    return '${v.substring(0, 6)}...${v.substring(v.length - 4)}';
  }
  return v;
}

/// A cross-chain swap widget: chain/token selectors, live quoting shimmer,
/// flip, destination address, and an in-card token-picker sheet — the Flutter
/// port of beUI's `MultiChainSwap` block.
///
/// Demo-grade like the source: the "quote" is `usd(from)/usd(to)` behind a
/// 450ms shimmer, and the action button doesn't submit anywhere.
class BeuiMultiChainSwap extends StatefulWidget {
  /// Creates a swap card.
  const BeuiMultiChainSwap({
    this.chains = beuiDefaultSwapChains,
    this.tokens = beuiDefaultSwapTokens,
    this.defaultFromId = 'eth-eth',
    this.defaultToId = 'sol-sol',
    super.key,
  });

  /// Selectable chains.
  final List<BeuiChain> chains;

  /// Selectable tokens.
  final List<BeuiToken> tokens;

  /// Initial pay-side token id.
  final String defaultFromId;

  /// Initial receive-side token id.
  final String defaultToId;

  @override
  State<BeuiMultiChainSwap> createState() => _BeuiMultiChainSwapState();
}

class _BeuiMultiChainSwapState extends State<BeuiMultiChainSwap> {
  late String _fromId = widget.defaultFromId;
  late String _toId = widget.defaultToId;
  final TextEditingController _amount = TextEditingController(text: '1');
  double _flipRot = 0;
  bool _quoting = false;
  Timer? _quoteTimer;
  BeuiTokenSide? _picking;
  bool _showDest = false;
  final TextEditingController _dest = TextEditingController();

  BeuiToken _token(String id) => widget.tokens.firstWhere((t) => t.id == id);
  BeuiChain _chain(String id) => widget.chains.firstWhere((c) => c.id == id);

  double get _numericAmount => double.tryParse(_amount.text) ?? 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _quoteTimer?.cancel();
    _amount.dispose();
    _dest.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _picking != null) {
      setState(() => _picking = null);
      return true;
    }
    return false;
  }

  /// 450ms shimmer while the demo "quote" refreshes (source effect).
  void _requote() {
    if (_numericAmount == 0) return;
    _quoteTimer?.cancel();
    setState(() => _quoting = true);
    _quoteTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _quoting = false);
    });
  }

  void _flip() {
    setState(() {
      _flipRot += 180;
      final from = _fromId;
      _fromId = _toId;
      _toId = from;
    });
    _requote();
  }

  void _pickToken(String id) {
    final picking = _picking;
    if (picking == null) return;
    setState(() {
      if (picking == BeuiTokenSide.from) {
        if (id == _toId) _toId = _fromId;
        _fromId = id;
      } else {
        if (id == _fromId) _fromId = _toId;
        _toId = id;
      }
      _picking = null;
    });
    _requote();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final from = _token(_fromId);
    final to = _token(_toId);
    final rate = (from.usd != null && to.usd != null && to.usd! > 0)
        ? from.usd! / to.usd!
        : 1.0;
    final toAmount = _numericAmount * rate;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: h-12, border-b, px-3.
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.border.withValues(alpha: colors.border.a * 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Swap',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: colors.foreground,
                  ),
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Settings',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      LucideIcons.settings,
                      size: 16,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16), // p-4
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fields with the flip button floating on their seam.
              Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    // gap-1.5 (6) + the flip wrapper's own `-my-4` box
                    // (h-9 36px less 32px of negative margin = 4) + gap-1.5.
                    spacing: 16,
                    children: [
                      _Field(
                        side: BeuiTokenSide.from,
                        token: from,
                        chain: _chain(from.chainId),
                        amountController: _amount,
                        quoting: false,
                        reduce: reduce,
                        colors: colors,
                        onAmountChanged: (_) {
                          setState(() {});
                          _requote();
                        },
                        onOpenPicker: () =>
                            setState(() => _picking = BeuiTokenSide.from),
                      ),
                      _Field(
                        side: BeuiTokenSide.to,
                        token: to,
                        chain: _chain(to.chainId),
                        amountText: toAmount > 0 ? formatAmount(toAmount) : '',
                        quoting: _quoting,
                        reduce: reduce,
                        colors: colors,
                        onOpenPicker: () =>
                            setState(() => _picking = BeuiTokenSide.to),
                      ),
                    ],
                  ),
                  _FlipButton(
                    rotation: _flipRot,
                    reduce: reduce,
                    colors: colors,
                    onPressed: _flip,
                  ),
                ],
              ),
              const SizedBox(height: 18), // gap-1.5 + mt-3
              _QuoteRow(
                from: from,
                to: to,
                rate: rate,
                quoting: _quoting,
                colors: colors,
              ),
              const SizedBox(height: 10), // gap-1.5 + mt-1
              _DestinationRow(
                show: _showDest,
                controller: _dest,
                reduce: reduce,
                colors: colors,
                onToggle: () => setState(() {
                  if (_showDest) _dest.clear();
                  _showDest = !_showDest;
                }),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18), // gap-1.5 + mt-3
              _ActionButton(
                from: from,
                to: to,
                amount: _numericAmount,
                destAddress: _dest.text,
                reduce: reduce,
                colors: colors,
              ),
            ],
          ),
        ),
      ],
    );

    // The picker is card-local (the source's absolute sheet), so the whole
    // card is a Stack the sheet slides within.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(
            color: colors.border.withValues(alpha: colors.border.a * 0.2),
          ),
          borderRadius: BorderRadius.circular(24), // rounded-3xl
        ),
        child: Stack(
          children: [
            body,
            BeuiTokenPicker(
              open: _picking != null,
              side: _picking,
              chains: widget.chains,
              tokens: widget.tokens,
              selectedId: _picking == BeuiTokenSide.from ? _fromId : _toId,
              onPick: _pickToken,
              onClose: () => setState(() => _picking = null),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.side,
    required this.token,
    required this.chain,
    required this.quoting,
    required this.reduce,
    required this.colors,
    required this.onOpenPicker,
    this.amountController,
    this.amountText,
    this.onAmountChanged,
  });

  final BeuiTokenSide side;
  final BeuiToken token;
  final BeuiChain chain;
  final TextEditingController? amountController;
  final String? amountText;
  final bool quoting;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<String>? onAmountChanged;
  final VoidCallback onOpenPicker;

  bool get _editable => amountController != null;

  @override
  Widget build(BuildContext context) {
    final amount = _editable ? amountController!.text : (amountText ?? '');
    final usdValue = (double.tryParse(amount) ?? 0) * (token.usd ?? 0);
    final amountStyle = TextStyle(
      fontSize: 24, // text-2xl
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: colors.foreground,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14), // p-3.5
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.4),
        border: Border.all(
          color: colors.border.withValues(alpha: colors.border.a * 0.5),
        ),
        borderRadius: BorderRadius.circular(16), // rounded-2xl
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (side == BeuiTokenSide.from ? 'You pay' : 'You get').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8, // tracking-wider
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8), // mb-2
          Row(
            spacing: 12, // gap-3
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_editable)
                      TextField(
                        controller: amountController,
                        onChanged: (v) {
                          final sanitized = sanitizeAmount(v);
                          if (sanitized != v) {
                            amountController!.value = TextEditingValue(
                              text: sanitized,
                              selection: TextSelection.collapsed(
                                offset: sanitized.length,
                              ),
                            );
                          }
                          onAmountChanged?.call(sanitized);
                        },
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: amountStyle,
                        cursorColor: colors.foreground,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: amountStyle.copyWith(
                            color: colors.mutedForeground.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 36, // h-9
                        child: Row(
                          spacing: 8,
                          children: [
                            // Quote shimmer: dim + 2px blur while refreshing.
                            _QuoteShimmer(
                              quoting: quoting,
                              reduce: reduce,
                              child: Text(
                                amount.isEmpty ? '0' : amount,
                                style: amountStyle,
                              ),
                            ),
                            if (quoting)
                              SwapSpinner(
                                size: 16,
                                color: colors.mutedForeground,
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ \$${formatAmount(usdValue, 2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              _TokenButton(
                token: token,
                chain: chain,
                colors: colors,
                onPressed: onOpenPicker,
              ),
            ],
          ),
          const SizedBox(height: 8), // mt-2
          Row(
            children: [
              Icon(LucideIcons.wallet, size: 12, color: colors.mutedForeground),
              const SizedBox(width: 4),
              Text(
                '${token.balance != null ? formatAmount(token.balance!) : '0.00'}'
                ' · ${chain.name}',
                style: TextStyle(
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colors.mutedForeground,
                ),
              ),
              const Spacer(),
              if (side == BeuiTokenSide.from && (token.balance ?? 0) > 0)
                Semantics(
                  button: true,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        // Source sets `String(token.balance)` — the raw,
                        // ungrouped number so it re-parses. formatAmount()
                        // thousands-groups (e.g. "4,521") which breaks
                        // double.tryParse → the amount would read 0; run the
                        // raw value through the same sanitizeAmount path the
                        // manual input uses.
                        final text = sanitizeAmount(rawAmount(token.balance!));
                        amountController?.text = text;
                        onAmountChanged?.call(text);
                      },
                      child: Text(
                        'MAX',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dim + blur while the quote refreshes (source: opacity 0.55, blur 2px,
/// 180ms EASE_OUT). Reduced motion keeps the dim only.
class _QuoteShimmer extends StatelessWidget {
  const _QuoteShimmer({
    required this.quoting,
    required this.reduce,
    required this.child,
  });

  final bool quoting;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget body = AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: beuiEaseOut,
      opacity: quoting ? 0.55 : 1,
      child: child,
    );
    if (quoting && !reduce) {
      body = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: beuiBlurSigma(2),
          sigmaY: beuiBlurSigma(2),
        ),
        child: body,
      );
    }
    return body;
  }
}

class _TokenButton extends StatelessWidget {
  const _TokenButton({
    required this.token,
    required this.chain,
    required this.colors,
    required this.onPressed,
  });

  final BeuiToken token;
  final BeuiChain chain;
  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Select token',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            height: 40, // h-10
            padding: const EdgeInsets.only(left: 4, right: 10),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8, // gap-2
              children: [
                SwapTokenDot(token: token, chain: chain, colors: colors),
                Text(
                  token.symbol,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                Icon(
                  LucideIcons.chevron_down,
                  size: 14,
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

class _FlipButton extends StatefulWidget {
  const _FlipButton({
    required this.rotation,
    required this.reduce,
    required this.colors,
    required this.onPressed,
  });

  final double rotation;
  final bool reduce;
  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  State<_FlipButton> createState() => _FlipButtonState();
}

class _FlipButtonState extends State<_FlipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    Widget body = Container(
      width: 36, // h-9 w-9
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: 0.1),
          colors.card,
        ),
        border: Border.all(color: colors.card, width: 3), // border-[3px] card
        shape: BoxShape.circle,
      ),
      child: Icon(
        LucideIcons.arrow_down_up,
        size: 14,
        color: colors.foreground,
      ),
    );

    // Accumulating 180° spins on a 380/26/0.6 spring; tap dips to 0.9.
    body = SingleMotionBuilder(
      value: widget.reduce ? 0.0 : widget.rotation,
      motion: _flipSpring,
      active: !widget.reduce,
      builder: (context, deg, child) =>
          Transform.rotate(angle: deg * math.pi / 180, child: child),
      child: body,
    );
    // Source's `whileTap` shares the flip's own transition (380/26/0.6), not a
    // separate press spring.
    body = SingleMotionBuilder(
      value: _pressed && !widget.reduce ? 0.9 : 1.0,
      motion: _flipSpring,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: body,
    );

    return Semantics(
      button: true,
      label: 'Reverse direction',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: body,
        ),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.from,
    required this.to,
    required this.rate,
    required this.quoting,
    required this.colors,
  });

  final BeuiToken from;
  final BeuiToken to;
  final double rate;
  final bool quoting;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(fontSize: 11, color: colors.mutedForeground);
    final value = TextStyle(
      fontSize: 11,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: colors.foreground,
    );

    Widget row(String name, Widget trailing) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(name, style: label),
          const Spacer(),
          trailing,
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.4),
        border: Border.all(
          color: colors.border.withValues(alpha: colors.border.a * 0.5),
        ),
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(
            'Rate',
            quoting
                ? SwapSpinner(size: 12, color: colors.mutedForeground)
                : Text(
                    '1 ${from.symbol} ≈ ${formatAmount(rate)} ${to.symbol}',
                    style: value,
                  ),
          ),
          row('Network fee', Text('\$0.42', style: value)),
          row('Slippage', Text('0.50%', style: value)),
          row('ETA', Text('≈ 24s', style: value)),
        ],
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.show,
    required this.controller,
    required this.reduce,
    required this.colors,
    required this.onToggle,
    required this.onChanged,
  });

  final bool show;
  final TextEditingController controller;
  final bool reduce;
  final BeuiColors colors;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final address = controller.text;
    final hasAddress = address.isNotEmpty;
    final valid = isValidAddress(address);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.4),
        border: Border.all(
          color: colors.border.withValues(alpha: colors.border.a * 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.send,
                        size: 14,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          show && hasAddress && valid
                              ? 'To: ${truncateAddress(address)}'
                              : 'Send to different address',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: !reduce && show ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        curve: beuiEaseOut,
                        child: Icon(
                          LucideIcons.chevron_down,
                          size: 14,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Height auto expand, 220ms EASE_OUT (fade-only under reduce).
          SingleMotionBuilder(
            value: show ? 1.0 : 0.0,
            motion: const CurvedMotion(
              Duration(milliseconds: 220),
              beuiEaseOut,
            ),
            active: !reduce,
            builder: (context, raw, child) {
              final t = raw.clamp(0.0, 1.0);
              if (t <= 0.001) return const SizedBox.shrink();
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: reduce ? 1 : t,
                  child: Opacity(opacity: t, child: child),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.border.withValues(
                      alpha: colors.border.a * 0.5,
                    ),
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasAddress && !valid
                        ? colors.destructive.withValues(alpha: 0.4)
                        : colors.border,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        onChanged: (v) => onChanged(v.trim()),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: colors.foreground,
                        ),
                        cursorColor: colors.foreground,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: '0x... or name.eth',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: colors.mutedForeground.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (hasAddress)
                      valid
                          ? Icon(
                              LucideIcons.check,
                              size: 14,
                              color: colors.primary,
                            )
                          : Semantics(
                              button: true,
                              label: 'Clear address',
                              child: GestureDetector(
                                onTap: () {
                                  controller.clear();
                                  onChanged('');
                                },
                                child: Icon(
                                  LucideIcons.x,
                                  size: 14,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.from,
    required this.to,
    required this.amount,
    required this.destAddress,
    required this.reduce,
    required this.colors,
  });

  final BeuiToken from;
  final BeuiToken to;
  final double amount;
  final String destAddress;
  final bool reduce;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    final noAmount = amount <= 0;
    final overBalance = from.balance != null && amount > from.balance!;
    final validDest = destAddress.isNotEmpty && isValidAddress(destAddress);
    final label = noAmount
        ? 'Enter an amount'
        : overBalance
        ? 'Insufficient ${from.symbol}'
        : validDest
        ? 'Swap + Send to ${truncateAddress(destAddress)}'
        : 'Swap ${from.symbol} → ${to.symbol}';
    final disabled = noAmount || overBalance;

    return Semantics(
      button: true,
      enabled: !disabled,
      child: MouseRegion(
        cursor: disabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        child: Container(
          height: 48, // h-12
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled
                ? colors.primary.withValues(alpha: 0.1)
                : colors.primary,
            borderRadius: BorderRadius.circular(16), // rounded-2xl
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 140), // label cross-fade
            switchInCurve: beuiEaseOut,
            switchOutCurve: beuiEaseOut,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.center,
              children: [...previous, ?current],
            ),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: disabled
                    ? colors.mutedForeground
                    : colors.primaryForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Token circle with the chain mini-badge on its corner (source `TokenDot`).
class SwapTokenDot extends StatelessWidget {
  /// Creates a token dot.
  const SwapTokenDot({
    required this.token,
    required this.chain,
    required this.colors,
    this.size = 28,
    super.key,
  });

  /// The token.
  final BeuiToken token;

  /// Its chain.
  final BeuiChain chain;

  /// Theme palette.
  final BeuiColors colors;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = chain.tone.resolve(colors);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: colors.border),
              shape: BoxShape.circle,
            ),
            child: Text(
              token.symbol.length > 2
                  ? token.symbol.substring(0, 2)
                  : token.symbol,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.background,
                border: Border.all(color: colors.card, width: 2),
                shape: BoxShape.circle,
              ),
              child: FittedBox(
                child: Text(
                  chain.symbol,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: tone.foreground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small spinning loader (Lucide `loader-2` analog): a rotating arc.
class SwapSpinner extends StatefulWidget {
  /// Creates a spinner.
  const SwapSpinner({required this.size, required this.color, super.key});

  /// Diameter.
  final double size;

  /// Stroke color.
  final Color color;

  @override
  State<SwapSpinner> createState() => _SwapSpinnerState();
}

class _SwapSpinnerState extends State<SwapSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _ArcPainter(color: widget.color, stroke: widget.size * 0.12),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: (size.shortestSide - stroke) / 2,
      ),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.color != color || old.stroke != stroke;
}
