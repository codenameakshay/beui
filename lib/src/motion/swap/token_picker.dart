import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';
import 'swap.dart';

/// The card-local token sheet of a [BeuiMultiChainSwap] (source
/// `TokenPicker`): slides up from the card's bottom edge on `SPRING_PANEL`
/// over a blurred backdrop, with search, chain-chip filters, a popular row
/// and the token list.
class BeuiTokenPicker extends StatefulWidget {
  /// Creates a token picker.
  const BeuiTokenPicker({
    required this.open,
    required this.side,
    required this.chains,
    required this.tokens,
    required this.selectedId,
    required this.onPick,
    required this.onClose,
    super.key,
  });

  /// Whether the sheet is up.
  final bool open;

  /// Which side is being picked for (labels the dialog).
  final BeuiTokenSide? side;

  /// Filterable chains.
  final List<BeuiChain> chains;

  /// Pickable tokens.
  final List<BeuiToken> tokens;

  /// Currently selected token id (highlighted row).
  final String selectedId;

  /// Fires with the picked token id.
  final ValueChanged<String> onPick;

  /// Fires on backdrop tap / close button.
  final VoidCallback onClose;

  @override
  State<BeuiTokenPicker> createState() => _BeuiTokenPickerState();
}

class _BeuiTokenPickerState extends State<BeuiTokenPicker> {
  bool _mounted = false;
  Timer? _unmountTimer;
  final TextEditingController _query = TextEditingController();
  String _chainFilter = 'all';

  @override
  void initState() {
    super.initState();
    _mounted = widget.open;
  }

  @override
  void didUpdateWidget(BeuiTokenPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _unmountTimer?.cancel();
      _query.clear(); // source resets the query on open
      setState(() => _mounted = true);
    } else if (!widget.open && oldWidget.open) {
      _unmountTimer?.cancel();
      _unmountTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _mounted = false);
      });
    }
  }

  @override
  void dispose() {
    _unmountTimer?.cancel();
    _query.dispose();
    super.dispose();
  }

  List<BeuiToken> get _filtered {
    final needle = _query.text.trim().toLowerCase();
    return widget.tokens.where((t) {
      if (_chainFilter != 'all' && t.chainId != _chainFilter) return false;
      if (needle.isEmpty) return true;
      final chain = widget.chains.where((c) => c.id == t.chainId).firstOrNull;
      return [
        t.symbol,
        t.name,
        chain?.name,
        t.address,
      ].any((h) => h?.toLowerCase().contains(needle) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final open = widget.open;

    return Positioned.fill(
      child: Stack(
        children: [
          // Backdrop: bg-background/40 + blur-sm, 200ms fade.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !open,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: beuiEaseOut,
                opacity: open ? 1 : 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: ColoredBox(
                        color: colors.background.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Sheet: y 100% → 0 on SPRING_PANEL (fade-only under reduce).
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.92,
                  ),
                  child: SingleMotionBuilder(
                    value: open ? 0.0 : 1.0,
                    from: 1.0,
                    motion: open
                        ? beuiSpringPanel
                        : const CurvedMotion(
                            Duration(milliseconds: 220),
                            beuiEaseOut,
                          ),
                    active: !reduce,
                    builder: (context, t, child) {
                      if (reduce) {
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: open ? 1 : 0,
                          child: child,
                        );
                      }
                      return FractionalTranslation(
                        translation: Offset(0, t.clamp(0.0, 1.0)),
                        child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: _sheet(colors),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheet(BeuiColors colors) {
    final filtered = _filtered;
    final popular = widget.tokens.where((t) => t.popular).take(6).toList();
    final showPopular = _query.text.isEmpty && _chainFilter == 'all';
    final sectionLabel = _query.text.isNotEmpty
        ? 'Results'
        : _chainFilter == 'all'
        ? 'Trending'
        : 'Tokens';

    BeuiChain? chainOf(BeuiToken t) =>
        widget.chains.where((c) => c.id == t.chainId).firstOrNull;

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: colors.mutedForeground,
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label:
          'Select ${widget.side == BeuiTokenSide.from ? 'from' : 'to'} token',
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.border)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 50,
              offset: Offset(0, 25),
              spreadRadius: -12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle.
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Search row.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                spacing: 8,
                children: [
                  Icon(
                    LucideIcons.search,
                    size: 16,
                    color: colors.mutedForeground,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(fontSize: 14, color: colors.foreground),
                      cursorColor: colors.foreground,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search name or paste address',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: colors.mutedForeground.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close',
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          LucideIcons.x,
                          size: 14,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Chain chips.
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 6,
                  children: [
                    _ChainChip(
                      active: _chainFilter == 'all',
                      label: 'All',
                      colors: colors,
                      onTap: () => setState(() => _chainFilter = 'all'),
                    ),
                    for (final chain in widget.chains)
                      _ChainChip(
                        active: _chainFilter == chain.id,
                        chain: chain,
                        colors: colors,
                        onTap: () => setState(() => _chainFilter = chain.id),
                      ),
                  ],
                ),
              ),
            ),
            // Body.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPopular && popular.isNotEmpty) ...[
                      sectionTitle('Most popular'),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          spacing: 6,
                          children: [
                            for (final t in popular)
                              if (chainOf(t) != null)
                                _PopularPill(
                                  token: t,
                                  chain: chainOf(t)!,
                                  colors: colors,
                                  onTap: () => widget.onPick(t.id),
                                ),
                          ],
                        ),
                      ),
                    ],
                    sectionTitle(sectionLabel),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No tokens found',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    for (final t in filtered)
                      if (chainOf(t) != null)
                        _TokenRow(
                          token: t,
                          chain: chainOf(t)!,
                          active: t.id == widget.selectedId,
                          colors: colors,
                          onTap: () => widget.onPick(t.id),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChainChip extends StatelessWidget {
  const _ChainChip({
    required this.active,
    required this.colors,
    required this.onTap,
    this.chain,
    this.label,
  });

  final bool active;
  final BeuiChain? chain;
  final String? label;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = chain?.tone.resolve(colors);
    return Semantics(
      button: true,
      selected: active,
      label: chain?.name ?? label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 36, // h-9
            width: chain != null ? 36 : null,
            padding: chain != null
                ? null
                : const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? colors.primary.withValues(alpha: 0.05)
                  : colors.background.withValues(alpha: 0.4),
              border: Border.all(
                color: active
                    ? colors.primary.withValues(alpha: 0.2)
                    : colors.border.withValues(alpha: 0.6),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: chain != null
                ? Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone!.background,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chain!.symbol,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: tone.foreground,
                      ),
                    ),
                  )
                : Text(
                    label!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PopularPill extends StatelessWidget {
  const _PopularPill({
    required this.token,
    required this.chain,
    required this.colors,
    required this.onTap,
  });

  final BeuiToken token;
  final BeuiChain chain;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: token.symbol,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.only(
              left: 4,
              right: 12,
              top: 4,
              bottom: 4,
            ),
            decoration: BoxDecoration(
              color: colors.background.withValues(alpha: 0.5),
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                SwapTokenDot(
                  token: token,
                  chain: chain,
                  colors: colors,
                  size: 22,
                ),
                Text(
                  token.symbol,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.token,
    required this.chain,
    required this.active,
    required this.colors,
    required this.onTap,
  });

  final BeuiToken token;
  final BeuiChain chain;
  final bool active;
  final BeuiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: active
                  ? colors.primary.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SwapTokenDot(
                  token: token,
                  chain: chain,
                  colors: colors,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        token.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        token.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  token.address ??
                      ((token.balance ?? 0) > 0
                          ? formatAmount(token.balance!)
                          : ''),
                  style: TextStyle(
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
