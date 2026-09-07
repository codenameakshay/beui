import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiMorphingModal].
Widget morphingModalDemo(BuildContext context) => const _ModalDemo();

/// A faithful port of the beUI morphing-modal preview — a wallet-options sheet
/// that morphs height between three views.
class _ModalDemo extends StatefulWidget {
  const _ModalDemo();

  @override
  State<_ModalDemo> createState() => _ModalDemoState();
}

class _ModalDemoState extends State<_ModalDemo> {
  String? _view; // 'options' | 'private-key' | 'recovery' | null

  void _go(String? v) => setState(() => _view = v);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BeuiButton(
              variant: BeuiButtonVariant.secondary,
              onPressed: () => _go('options'),
              child: const Text('Open wallet options'),
            ),
            const SizedBox(height: 12),
            Text(
              'Click a row. The modal morphs height to match new content.',
              style: TextStyle(fontSize: 12, color: colors.mutedForeground),
            ),
          ],
        ),
        BeuiMorphingModal(
          viewId: _view,
          onClose: () => _go(null),
          child: switch (_view) {
            'options' => _OptionsView(
              onPrivateKey: () => _go('private-key'),
              onRecovery: () => _go('recovery'),
              onClose: () => _go(null),
            ),
            'private-key' => _DetailView(
              icon: LucideIcons.lock,
              title: 'Private Key',
              description:
                  'Your Private Key is the key used to back up your wallet. '
                  'Keep it secret and secure at all times.',
              onBack: () => _go('options'),
              kind: _DetailKind.privateKey,
            ),
            'recovery' => _DetailView(
              icon: LucideIcons.scroll_text,
              title: 'Recovery Phrase',
              description:
                  '12 words you can use to restore your wallet on any device. '
                  'Write them down somewhere safe.',
              onBack: () => _go('options'),
              kind: _DetailKind.recovery,
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

class _OptionsView extends StatelessWidget {
  const _OptionsView({
    required this.onPrivateKey,
    required this.onRecovery,
    required this.onClose,
  });
  final VoidCallback onPrivateKey;
  final VoidCallback onRecovery;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _modalHeader('Options', onClose),
        const SizedBox(height: 16),
        _modalRow(LucideIcons.lock, 'View Private Key', onPrivateKey),
        const SizedBox(height: 8),
        _modalRow(LucideIcons.scroll_text, 'View Recovery Phrase', onRecovery),
        const SizedBox(height: 8),
        _modalRow(
          LucideIcons.trash,
          'Remove Wallet',
          onClose,
          destructive: true,
        ),
      ],
    );
  }
}

enum _DetailKind { privateKey, recovery }

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.icon,
    required this.title,
    required this.description,
    required this.onBack,
    required this.kind,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onBack;
  final _DetailKind kind;

  static const _words = [
    'mountain', 'river', 'candle', 'harbor', 'amber', 'violet', //
    'spring', 'ocean', 'marble', 'thunder', 'willow', 'crystal',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colors.foreground),
            _modalCircleClose(onBack),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(fontSize: 14, color: colors.mutedForeground),
        ),
        if (kind == _DetailKind.privateKey) ...[
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 16),
          _bullet(
            LucideIcons.shield_check,
            'Keep your private key safe',
            colors,
          ),
          const SizedBox(height: 10),
          _bullet(
            LucideIcons.scroll_text,
            "Don't share it with anyone else",
            colors,
          ),
          const SizedBox(height: 10),
          _bullet(
            LucideIcons.ban,
            "If you lose it, we can't recover it",
            colors,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _modalPill('Cancel', onBack, primary: false)),
              const SizedBox(width: 8),
              Expanded(
                child: _modalPill(
                  'Reveal',
                  onBack,
                  primary: true,
                  icon: LucideIcons.scan_face,
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 16),
          for (var r = 0; r < 4; r++) ...[
            if (r > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _wordCell(r * 3 + c, _words[r * 3 + c], colors),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
          _modalPill('Done', onBack, primary: true, fullWidth: true),
        ],
      ],
    );
  }
}

Widget _modalHeader(String title, VoidCallback onClose) => Builder(
  builder: (context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        _modalCircleClose(onClose),
      ],
    );
  },
);

Widget _modalCircleClose(VoidCallback onTap) => Builder(
  builder: (context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(LucideIcons.x, size: 16, color: colors.mutedForeground),
      ),
    );
  },
);

Widget _modalRow(
  IconData icon,
  String label,
  VoidCallback onTap, {
  bool destructive = false,
}) => Builder(
  builder: (context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final fg = destructive ? colors.destructive : colors.foreground;
    final bg = destructive
        ? colors.destructive.withValues(alpha: 0.10)
        : colors.foreground.withValues(alpha: 0.04);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16), // rounded-2xl
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

Widget _bullet(IconData icon, String text, BeuiColors colors) => Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Icon(icon, size: 16, color: colors.mutedForeground),
    const SizedBox(width: 10),
    Expanded(
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: colors.mutedForeground),
      ),
    ),
  ],
);

Widget _wordCell(int index, String word, BeuiColors colors) => Container(
  decoration: BoxDecoration(
    border: Border.all(color: colors.border),
    borderRadius: BorderRadius.circular(8), // rounded-lg
    color: colors.background.withValues(alpha: 0.40),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  child: Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '${index + 1}. ',
          style: TextStyle(color: colors.mutedForeground),
        ),
        TextSpan(
          text: word,
          style: TextStyle(color: colors.foreground),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 12),
  ),
);

Widget _modalPill(
  String label,
  VoidCallback onTap, {
  required bool primary,
  IconData? icon,
  bool fullWidth = false,
}) => Builder(
  builder: (context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final bg = primary
        ? colors.foreground
        : colors.foreground.withValues(alpha: 0.06);
    final fg = primary ? colors.background : colors.foreground;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20), // rounded-full (h-10)
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          width: fullWidth ? double.infinity : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
