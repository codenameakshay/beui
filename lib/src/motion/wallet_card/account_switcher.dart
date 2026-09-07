import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../_format.dart';
import '_constants.dart';
import '_morph.dart';
import '_types.dart';
import 'account_avatar.dart';
import 'copy_button.dart';

/// Account switcher whose trigger morphs into a panel that grows to full header
/// width (covering the header icons) and downward at the same time — the Flutter
/// port of the source's `AccountSwitcher`. Built on [MorphPanel].
class WalletAccountSwitcher extends StatefulWidget {
  /// Creates the switcher.
  const WalletAccountSwitcher({
    required this.accounts,
    required this.activeAccount,
    required this.onSelect,
    super.key,
  });

  /// All selectable accounts.
  final List<BeuiWalletAccount> accounts;

  /// The currently active account (drives the trigger label + selected row).
  final BeuiWalletAccount? activeAccount;

  /// Called with the chosen account id.
  final ValueChanged<String> onSelect;

  @override
  State<WalletAccountSwitcher> createState() => _WalletAccountSwitcherState();
}

class _WalletAccountSwitcherState extends State<WalletAccountSwitcher> {
  bool _open = false;

  void _close() {
    if (_open) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final active = widget.activeAccount;

    return MorphPanel(
      open: _open,
      onOpen: () => setState(() => _open = true),
      onDismiss: _close,
      armDelayMs: 280,
      trigger: _trigger(colors, active),
      panelBuilder: (context, info) => _panel(context, colors, info, active),
    );
  }

  Widget _trigger(BeuiColors colors, BeuiWalletAccount? active) {
    return Padding(
      padding: kHeadPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active != null) ...[
            BeuiAccountAvatar(account: active),
            const SizedBox(width: kHeadGap),
            Flexible(
              child: Text(
                active.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
              ),
            ),
            const SizedBox(width: kHeadGap),
            Icon(
              LucideIcons.chevron_down,
              size: 16,
              color: colors.mutedForeground,
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel(
    BuildContext context,
    BeuiColors colors,
    WalletMorphInfo info,
    BeuiWalletAccount? active,
  ) {
    // Content cross-fades in as the box grows so the panel body doesn't pop.
    final contentOpacity = ((info.progress - 0.15) / 0.85).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel header (mirrors the trigger; tapping it closes).
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: Padding(
            padding: kHeadPadding,
            child: Row(
              children: [
                if (active != null) BeuiAccountAvatar(account: active),
                const SizedBox(width: kHeadGap),
                Expanded(
                  child: Text(
                    active?.name ?? 'Select account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: kHeadGap),
                Transform.rotate(
                  angle: info.progress * math.pi,
                  child: Icon(
                    LucideIcons.chevron_down,
                    size: 16,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
        // List body — cross-fades + staggers in once armed.
        Opacity(
          opacity: contentOpacity,
          child: IgnorePointer(
            ignoring: !info.armed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 256),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.accounts.length; i++)
                      WalletRevealItem(
                        index: i,
                        child: _AccountRow(
                          account: widget.accounts[i],
                          selected: widget.accounts[i].id == active?.id,
                          armed: info.armed,
                          onTap: () {
                            widget.onSelect(widget.accounts[i].id);
                            _close();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends StatefulWidget {
  const _AccountRow({
    required this.account,
    required this.selected,
    required this.armed,
    required this.onTap,
  });

  final BeuiWalletAccount account;
  final bool selected;
  final bool armed;
  final VoidCallback onTap;

  @override
  State<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<_AccountRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);

    final hoverActive = widget.armed && _hovered && !widget.selected;
    final bg = widget.selected
        ? colors.muted
        : (hoverActive ? colors.muted : Colors.transparent);
    final textColor = widget.selected || hoverActive
        ? colors.foreground
        : colors.mutedForeground;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      BeuiAccountAvatar(account: widget.account),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            Text(
                              beuiTruncateAddress(widget.account.address),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.selected)
                        Icon(
                          LucideIcons.check,
                          size: 16,
                          color: colors.foreground,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            WalletCopyButton(value: widget.account.address),
          ],
        ),
      ),
    );
  }
}
