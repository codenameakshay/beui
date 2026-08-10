import 'package:flutter/material.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../../tokens/motion.dart';
import '../_engine.dart' show SingleMotionBuilder;
import '../action_swap.dart';
import '_morph.dart';
import '_types.dart';
import 'account_switcher.dart';
import 'actions.dart';
import 'balance_delta.dart';
import 'search_bar.dart';

export '_types.dart' show BeuiWalletAccount;

/// A composed wallet overview card — the Flutter port of beUI's `wallet-card`
/// block.
///
/// Combines four motion pieces on one surface:
/// * an **account switcher** whose trigger morphs open into a full-width panel
///   ([WalletAccountSwitcher], on the shared `kWalletMorph` spring),
/// * a **search icon** that morphs into a search bar ([WalletSearchBar]),
/// * a **rolling balance** ([BeuiActionSwapText] `cascade`) with an eye toggle
///   that masks it, and a transient [WalletBalanceDelta] change pill, and
/// * a row of **Send / Deposit / Swap / Buy** actions ([WalletActions]) with a
///   spring press.
///
/// Mirrors the source's controlled + uncontrolled account selection: pass
/// [accountId] + [onAccountChange] to control it, or omit [accountId] for
/// internal state seeded from [defaultAccountId]. Actions and search are plain
/// callbacks — the resulting flow is left to the consumer.
class BeuiWalletCard extends StatefulWidget {
  /// Creates a wallet card.
  const BeuiWalletCard({
    required this.accounts,
    required this.balance,
    this.accountId,
    this.defaultAccountId,
    this.onAccountChange,
    this.balancePrefix = r'$',
    this.defaultChange,
    this.defaultBalanceHidden = false,
    this.onSend,
    this.onDeposit,
    this.onSwap,
    this.onBuy,
    this.searchPlaceholder = 'Search',
    this.searchRecent = const [],
    this.onSearchChange,
    this.onSearchSubmit,
    this.hasNotifications = false,
    this.onNotifications,
    super.key,
  });

  /// The selectable accounts (first is the default active one).
  final List<BeuiWalletAccount> accounts;

  /// The balance shown, rolling on change.
  final double balance;

  /// Controlled active account id. When null the card manages its own.
  final String? accountId;

  /// Initial active account id when uncontrolled.
  final String? defaultAccountId;

  /// Notified when the active account changes.
  final ValueChanged<String>? onAccountChange;

  /// Currency prefix (source `balancePrefix`, default `$`).
  final String balancePrefix;

  /// Initial change shown in the delta pill before any live change.
  final double? defaultChange;

  /// Start with the balance masked behind dots.
  final bool defaultBalanceHidden;

  /// Action callbacks.
  final VoidCallback? onSend;

  /// Action callbacks.
  final VoidCallback? onDeposit;

  /// Action callbacks.
  final VoidCallback? onSwap;

  /// Action callbacks.
  final VoidCallback? onBuy;

  /// Search input placeholder.
  final String searchPlaceholder;

  /// Recent searches shown in the expanded search panel.
  final List<String> searchRecent;

  /// Called on each search keystroke.
  final ValueChanged<String>? onSearchChange;

  /// Called on search submit.
  final ValueChanged<String>? onSearchSubmit;

  /// Show an unread pulse on the notifications bell.
  final bool hasNotifications;

  /// Called when the bell is tapped.
  final VoidCallback? onNotifications;

  @override
  State<BeuiWalletCard> createState() => _BeuiWalletCardState();
}

class _BeuiWalletCardState extends State<BeuiWalletCard> {
  final GlobalKey _headerKey = GlobalKey();
  final LayerLink _headerLink = LayerLink();

  late String? _internalAccountId =
      widget.defaultAccountId ??
      (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
  late bool _balanceHidden = widget.defaultBalanceHidden;

  String? get _activeId => widget.accountId ?? _internalAccountId;

  BeuiWalletAccount? get _active {
    for (final a in widget.accounts) {
      if (a.id == _activeId) return a;
    }
    return widget.accounts.isNotEmpty ? widget.accounts.first : null;
  }

  void _handleAccountChange(String id) {
    if (widget.accountId == null) setState(() => _internalAccountId = id);
    widget.onAccountChange?.call(id);
  }

  String _formatBalance() {
    final v = widget.balance;
    final whole = v.truncate().abs();
    final cents = ((v - v.truncate()).abs() * 100).round().toString().padLeft(
      2,
      '0',
    );
    final digits = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${widget.balancePrefix}$buf.$cents';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    final shown = _formatBalance();
    const masked = '*******'; // 7 dots, source `"*".repeat(7)`

    return Container(
      constraints: const BoxConstraints(maxWidth: 320), // max-w-xs
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(32), // rounded-4xl
      ),
      padding: const EdgeInsets.all(24), // p-6
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row: account switcher + search + bell. Shared morph anchor.
          WalletHeaderScope(
            headerLink: _headerLink,
            headerKey: _headerKey,
            child: CompositedTransformTarget(
              link: _headerLink,
              child: SizedBox(
                key: _headerKey,
                child: Row(
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: WalletAccountSwitcher(
                          accounts: widget.accounts,
                          activeAccount: _active,
                          onSelect: _handleAccountChange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    WalletSearchBar(
                      placeholder: widget.searchPlaceholder,
                      recent: widget.searchRecent,
                      onChanged: widget.onSearchChange,
                      onSubmitted: widget.onSearchSubmit,
                    ),
                    const SizedBox(width: 4),
                    _BellButton(
                      hasNotifications: widget.hasNotifications,
                      onTap: widget.onNotifications,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Balance block.
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 12, // text-xs
                      height: 16 / 12, // …/16
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _EyeToggle(
                    hidden: _balanceHidden,
                    onTap: () =>
                        setState(() => _balanceHidden = !_balanceHidden),
                  ),
                ],
              ),
              // No gap here: the source stacks the label row and the amount
              // directly inside `flex flex-col items-center`.
              BeuiActionSwapText(
                value: _balanceHidden ? 'hidden' : shown,
                text: _balanceHidden ? masked : shown,
                variant: BeuiActionSwapVariant.cascade,
                style: TextStyle(
                  fontSize: 30, // text-3xl
                  height: 36 / 30, // …/36
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              if (_balanceHidden)
                Container(
                  // `mt-2 flex h-7` — same row box as the delta it replaces.
                  margin: const EdgeInsets.only(top: 8),
                  height: 28,
                  child: Center(
                    child: Text(
                      '*****',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: colors.mutedForeground,
                        letterSpacing: 4.2, // tracking-[0.3em]
                      ),
                    ),
                  ),
                )
              else
                WalletBalanceDelta(
                  balance: widget.balance,
                  initialChange: widget.defaultChange,
                ),
            ],
          ),

          const SizedBox(height: 32),

          WalletActions(
            onSend: widget.onSend,
            onDeposit: widget.onDeposit,
            onSwap: widget.onSwap,
            onBuy: widget.onBuy,
          ),
        ],
      ),
    );
  }
}

/// The show/hide-balance toggle (source's inline eye button).
class _EyeToggle extends StatefulWidget {
  const _EyeToggle({required this.hidden, required this.onTap});
  final bool hidden;
  final VoidCallback onTap;

  @override
  State<_EyeToggle> createState() => _EyeToggleState();
}

class _EyeToggleState extends State<_EyeToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    return Semantics(
      button: true,
      label: widget.hidden ? 'Show balance' : 'Hide balance',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Icon(
            widget.hidden ? LucideIcons.eye_off : LucideIcons.eye,
            size: 14,
            color: _hovered ? colors.foreground : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

/// The notifications bell with a spring press and an optional unread pulse
/// (source `animate-ping` dot).
class _BellButton extends StatefulWidget {
  const _BellButton({required this.hasNotifications, this.onTap});
  final bool hasNotifications;
  final VoidCallback? onTap;

  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _hovered = false;
  AnimationController? _ping;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.hasNotifications && !reduce && _ping == null) {
      _ping = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _ping?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final target = (_pressed && !reduce) ? 0.9 : 1.0;

    return Semantics(
      button: true,
      label: 'Notifications',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: SingleMotionBuilder(
              value: target,
              motion: beuiSpringPress,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hovered ? colors.muted : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(LucideIcons.bell, size: 16, color: colors.foreground),
                    if (widget.hasNotifications)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: _PulseDot(color: colors.primary, ping: _ping),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color, required this.ping});
  final Color color;
  final AnimationController? ping;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    final controller = ping;
    if (controller == null) return dot;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            return Opacity(
              opacity: (0.6 * (1 - t)).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1 + t,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
        dot,
      ],
    );
  }
}
