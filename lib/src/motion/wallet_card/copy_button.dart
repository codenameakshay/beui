import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../action_swap.dart';

/// Copies [value] to the clipboard and swaps the copy icon for a check via
/// [BeuiActionSwapIcon] (`cascade`) — the Flutter port of the source's
/// `CopyButton`. Reverts after 1400ms.
class WalletCopyButton extends StatefulWidget {
  /// Creates a copy button for [value].
  const WalletCopyButton({required this.value, super.key});

  /// The text copied to the clipboard on tap.
  final String value;

  @override
  State<WalletCopyButton> createState() => _WalletCopyButtonState();
}

class _WalletCopyButtonState extends State<WalletCopyButton> {
  bool _copied = false;
  bool _hovered = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);

    return Semantics(
      button: true,
      label: _copied ? 'Copied' : 'Copy address',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _copy,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered ? colors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconTheme.merge(
              // Check draws in the success accent (source `text-emerald-500`);
              // the copy glyph reads as muted foreground.
              data: IconThemeData(
                color: _copied
                    ? colors.success
                    : (_hovered ? colors.foreground : colors.mutedForeground),
              ),
              child: BeuiActionSwapIcon(
                value: _copied ? 'check' : 'copy',
                icon: _copied ? LucideIcons.check : LucideIcons.copy,
                variant: BeuiActionSwapVariant.cascade,
                size: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
