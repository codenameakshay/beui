// Core component demos extracted from the gallery's original main.dart.
//
// These are the "inline" demos (switch, checkbox, radio, tabs, button, tooltip,
// drawer, morphing-modal, tilt-card, dock, marquee, shared-layout, action-swap,
// text-animation) that don't have their own demo file. Each public builder is
// wired into the explorer catalog in `explorer/catalog.dart`.
import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

Widget actionSwapDemo(BuildContext context) => const _ActionSwapDemo();

Widget textAnimationDemo(BuildContext context) => const _TextAnimationDemo();

Widget switchDemo(BuildContext context) => const _SwitchDemo();

Widget checkboxDemo(BuildContext context) => const _CheckboxDemo();

Widget radioDemo(BuildContext context) => const _RadioDemo();

Widget tabsDemo(BuildContext context) => const _TabsDemo();

Widget buttonDemo(BuildContext context) => const _ButtonDemo();

Widget drawerDemo(BuildContext context) => const _DrawerDemo();

Widget morphingModalDemo(BuildContext context) => const _ModalDemo();

Widget tiltCardDemo(BuildContext context) {
  final colors = Theme.of(context).extension<BeuiColors>()!;
  return BeuiTiltCard(
    child: Container(
      width: 280,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Source: `text-xs uppercase tracking-wider text-muted-foreground`
          // — 12px, 0.05em tracking, regular weight (no font-weight class).
          Text(
            'PREMIUM',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tilt me',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Move your cursor across the card to see 3D tilt + glare.',
            style: TextStyle(fontSize: 14, color: colors.mutedForeground),
          ),
        ],
      ),
    ),
  );
}

Widget dockDemo(BuildContext context) => const _DockDemo();

Widget marqueeDemo(BuildContext context) {
  final colors = Theme.of(context).extension<BeuiColors>()!;
  const logos = [
    'Vercel',
    'Linear',
    'Stripe',
    'Figma',
    'GitHub',
    'Notion',
    'Loom',
    'Raycast',
  ];
  // Mirrors MarqueePreview: a `w-full` marquee whose cards carry `mx-4`
  // (16px) on top of the track's own 16px gap.
  return SizedBox(
    width: double.infinity,
    child: BeuiMarquee(
      duration: const Duration(seconds: 25),
      children: [
        for (final l in logos)
          Container(
            height: 48,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              l,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget sharedLayoutDemo(BuildContext context) {
  const items = [
    ('Inbox', '12 unread threads, 3 mentions today.'),
    ('Drafts', '4 posts waiting for a final pass.'),
    ('Releases', 'Last shipped 2 days ago, v0.4.1.'),
    ('Billing', 'Plan renews on the 1st of next month.'),
  ];
  // Mirrors SharedLayoutBgPreview: `w-full max-w-lg px-2` (512px cap, 8px
  // horizontal padding) around the row list.
  return SizedBox(
    width: 512,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: BeuiSharedLayoutBg(
        children: [
          for (final (title, body) in items)
            _SharedRow(title: title, body: body),
        ],
      ),
    ),
  );
}

/// A list row whose trailing arrow nudges up-right on hover (the source's
/// `group-hover:translate-x-0.5 -translate-y-0.5`).
class _SharedRow extends StatefulWidget {
  const _SharedRow({required this.title, required this.body});
  final String title;
  final String body;

  @override
  State<_SharedRow> createState() => _SharedRowState();
}

class _SharedRowState extends State<_SharedRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                  ),
                ),
                AnimatedSlide(
                  offset: _hovered ? const Offset(0.14, -0.14) : Offset.zero,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Icon(
                    LucideIcons.arrow_up_right,
                    size: 14,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.body,
              style: TextStyle(fontSize: 14, color: colors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

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
          LucideIcons.trash_2,
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

/// Exercises the modal drawer from either edge.
class _DrawerDemo extends StatefulWidget {
  const _DrawerDemo();

  @override
  State<_DrawerDemo> createState() => _DrawerDemoState();
}

class _DrawerDemoState extends State<_DrawerDemo> {
  bool _open = false;
  BeuiDrawerSide _side = BeuiDrawerSide.right;

  void _show(BeuiDrawerSide side) => setState(() {
    _side = side;
    _open = true;
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            BeuiButton(
              onPressed: () => _show(BeuiDrawerSide.left),
              child: const Text('Open left'),
            ),
            BeuiButton(
              onPressed: () => _show(BeuiDrawerSide.right),
              child: const Text('Open right'),
            ),
          ],
        ),
        BeuiDrawer(
          open: _open,
          side: _side,
          label: 'Menu',
          onOpenChange: (v) => setState(() => _open = v),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                for (final item in const [
                  'Profile',
                  'Account',
                  'Notifications',
                  'Privacy',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(item, style: const TextStyle(fontSize: 16)),
                  ),
                const Spacer(),
                BeuiButton(
                  variant: BeuiButtonVariant.outline,
                  onPressed: () => setState(() => _open = false),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget tooltipDemo(BuildContext context) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    const Text('Hover (or long-press on touch) a button:'),
    const SizedBox(height: 24),
    Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final (side, label) in const [
          (BeuiTooltipSide.top, 'Top'),
          (BeuiTooltipSide.bottom, 'Bottom'),
          (BeuiTooltipSide.left, 'Left'),
          (BeuiTooltipSide.right, 'Right'),
        ])
          BeuiTooltip(
            side: side,
            content: Text('Tooltip on $label'),
            child: BeuiButton(
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: Text(label),
            ),
          ),
      ],
    ),
  ],
);

/// Exercises button variants, sizes, the stateful lifecycle, and magnetic pull.
class _ButtonDemo extends StatefulWidget {
  const _ButtonDemo();

  @override
  State<_ButtonDemo> createState() => _ButtonDemoState();
}

class _ButtonDemoState extends State<_ButtonDemo> {
  BeuiButtonState _state = BeuiButtonState.idle;

  void _runLifecycle() async {
    setState(() => _state = BeuiButtonState.loading);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _state = BeuiButtonState.success);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _state = BeuiButtonState.idle);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            BeuiButton(
              onPressed: () {},
              child: _row(const [
                Text('Continue'),
                Icon(LucideIcons.arrow_right),
              ]),
            ),
            BeuiButton(
              variant: BeuiButtonVariant.secondary,
              onPressed: () {},
              child: _row(const [Icon(LucideIcons.download), Text('Download')]),
            ),
            BeuiButton(
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Text('Outline'),
            ),
            BeuiButton(
              variant: BeuiButtonVariant.ghost,
              onPressed: () {},
              child: const Text('Ghost'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BeuiButton(
              size: BeuiButtonSize.sm,
              onPressed: () {},
              child: const Text('Small'),
            ),
            BeuiButton(
              size: BeuiButtonSize.md,
              onPressed: () {},
              child: const Text('Medium'),
            ),
            BeuiButton(
              size: BeuiButtonSize.lg,
              onPressed: () {},
              child: const Text('Large'),
            ),
            BeuiButton(
              size: BeuiButtonSize.icon,
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Icon(LucideIcons.trash_2),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            BeuiButton(
              ripple: true,
              onPressed: () {},
              child: const Text('Ripple'),
            ),
            BeuiButton(
              ripple: true,
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Text('Tap me'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BeuiStatefulButton(
              label: 'Save changes',
              icon: LucideIcons.arrow_right,
              state: _state,
              onPressed: _runLifecycle,
            ),
            BeuiButton(
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Text('Submit'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            BeuiMagneticButton(
              onPressed: () {},
              child: _row(const [
                Text('Hover me'),
                Icon(LucideIcons.arrow_right),
              ]),
            ),
            BeuiMagneticButton(
              variant: BeuiButtonVariant.outline,
              strength: 0.15,
              onPressed: () {},
              child: const Text('Subtle pull'),
            ),
            BeuiMagneticButton(
              variant: BeuiButtonVariant.outline,
              strength: 0.4,
              onPressed: () {},
              child: const Text('Strong pull'),
            ),
          ],
        ),
      ],
    );
  }

  /// A min-width row with the source button's 8px gap between children.
  Widget _row(List<Widget> children) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        children[i],
      ],
    ],
  );
}

/// Exercises all three tab variants and a fading content panel.
class _TabsDemo extends StatefulWidget {
  const _TabsDemo();

  @override
  State<_TabsDemo> createState() => _TabsDemoState();
}

class _TabsDemoState extends State<_TabsDemo> {
  // Mirrors TabsPreview: three independently-stated groups, one per variant,
  // each under an uppercase section label.
  String _pill = 'overview';
  String _segment = 'day';
  String _underline = 'all';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final body = TextStyle(fontSize: 14, color: colors.mutedForeground);

    // Outer `flex flex-col gap-8` (32px).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _tabsSection(
          colors,
          'Pill',
          BeuiTabs<String>(
            variant: BeuiTabsVariant.pill,
            value: _pill,
            onChanged: (v) => setState(() => _pill = v),
            tabs: [
              BeuiTab(
                value: 'overview',
                label: const Text('Overview'),
                content: Text('High-level summary.', style: body),
              ),
              BeuiTab(
                value: 'activity',
                label: const Text('Activity'),
                content: Text('Recent events.', style: body),
              ),
              BeuiTab(
                value: 'settings',
                label: const Text('Settings'),
                content: Text('Preferences.', style: body),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _tabsSection(
          colors,
          'Segment',
          BeuiTabs<String>(
            variant: BeuiTabsVariant.segment,
            value: _segment,
            onChanged: (v) => setState(() => _segment = v),
            tabs: const [
              BeuiTab(value: 'day', label: Text('Day')),
              BeuiTab(value: 'week', label: Text('Week')),
              BeuiTab(value: 'month', label: Text('Month')),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _tabsSection(
          colors,
          'Underline',
          BeuiTabs<String>(
            variant: BeuiTabsVariant.underline,
            value: _underline,
            onChanged: (v) => setState(() => _underline = v),
            tabs: const [
              BeuiTab(value: 'all', label: Text('All')),
              BeuiTab(value: 'open', label: Text('Open')),
              BeuiTab(value: 'closed', label: Text('Closed')),
            ],
          ),
        ),
      ],
    );
  }

  /// `flex flex-col gap-2` under a `text-[10px] font-semibold uppercase
  /// tracking-wider text-muted-foreground` caption.
  Widget _tabsSection(BeuiColors colors, String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5, // tracking-wider (0.05em)
          color: colors.mutedForeground,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

/// Exercises the radio group's gliding selection dot.
class _RadioDemo extends StatefulWidget {
  const _RadioDemo();

  @override
  State<_RadioDemo> createState() => _RadioDemoState();
}

class _RadioDemoState extends State<_RadioDemo> {
  String _plan = 'pro';

  @override
  Widget build(BuildContext context) {
    return BeuiRadioGroup<String>(
      value: _plan,
      onChanged: (v) => setState(() => _plan = v),
      items: const [
        BeuiRadioItem(value: 'starter', label: 'Starter — free'),
        BeuiRadioItem(value: 'pro', label: 'Pro — \$12/mo'),
        BeuiRadioItem(value: 'team', label: 'Team — \$29/mo'),
        BeuiRadioItem(value: 'legacy', label: 'Legacy plan', enabled: false),
      ],
    );
  }
}

/// Exercises the checkbox's states, including indeterminate and disabled.
class _CheckboxDemo extends StatefulWidget {
  const _CheckboxDemo();

  @override
  State<_CheckboxDemo> createState() => _CheckboxDemoState();
}

class _CheckboxDemoState extends State<_CheckboxDemo> {
  bool _terms = true;
  bool _updates = false;

  @override
  Widget build(BuildContext context) {
    // Mirrors CheckboxPreview: `flex flex-col gap-3` (12px).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BeuiCheckbox(
          value: _terms,
          label: 'Accept terms and conditions',
          onChanged: (v) => setState(() => _terms = v),
        ),
        const SizedBox(height: 12),
        BeuiCheckbox(
          value: _updates,
          label: 'Email me product updates',
          onChanged: (v) => setState(() => _updates = v),
        ),
        const SizedBox(height: 12),
        BeuiCheckbox(
          value: true,
          indeterminate: true,
          label: 'Select all (partial)',
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        BeuiCheckbox(
          value: true,
          enabled: false,
          label: 'Disabled',
          onChanged: (_) {},
        ),
      ],
    );
  }
}

/// Exercises the switch's variants and states (the gallery doubles as visual QA).
class _SwitchDemo extends StatefulWidget {
  const _SwitchDemo();

  @override
  State<_SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<_SwitchDemo> {
  bool _notifications = true;
  bool _off = false;

  @override
  Widget build(BuildContext context) {
    // Mirrors SwitchPreview: `flex flex-col gap-3` (12px) with the three
    // labels the source ships. Preview parity is part of the port (spec §11).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BeuiSwitch(
          value: _notifications,
          label: 'Enable notifications',
          onChanged: (v) => setState(() => _notifications = v),
        ),
        const SizedBox(height: 12),
        BeuiSwitch(
          value: _off,
          label: 'Off',
          onChanged: (v) => setState(() => _off = v),
        ),
        const SizedBox(height: 12),
        BeuiSwitch(
          value: true,
          enabled: false,
          label: 'Disabled',
          onChanged: (_) {},
        ),
      ],
    );
  }
}

/// The dock: faithful by default (flat bar + gliding active pill), with an
/// opt-in `magnify: true` variant below showing the Flutter-only enhancement.
class _DockDemo extends StatefulWidget {
  const _DockDemo();

  @override
  State<_DockDemo> createState() => _DockDemoState();
}

class _DockDemoState extends State<_DockDemo> {
  String _active = 'home';

  static const _items = <(String, IconData)>[
    ('home', LucideIcons.house),
    ('mail', LucideIcons.mail),
    ('calendar', LucideIcons.calendar),
    ('music', LucideIcons.music),
    ('discover', LucideIcons.sparkles),
  ];

  List<BeuiDockItem> _buildItems() => [
    for (final (id, icon) in _items)
      BeuiDockItem(
        icon: icon,
        tooltip: id,
        active: _active == id,
        onTap: () => setState(() => _active = id),
      ),
    // Groups the settings action away from the five navigation actions
    // (source: DockSeparator).
    const BeuiDockItem.separator(),
    BeuiDockItem(
      icon: LucideIcons.settings,
      tooltip: 'settings',
      active: _active == 'settings',
      onTap: () => setState(() => _active = 'settings'),
    ),
    // Source: a trailing GitHub item that carries its own link, so it has no
    // active state and never joins the pill's selection. Lucide dropped brand
    // marks, so the source's inline `GithubIcon` svg ports to a CustomPaint
    // (spec §3: hand-drawn marks are painted, never bundled as assets).
    const BeuiDockItem(child: _GithubMark(), tooltip: 'GitHub'),
  ];

  @override
  Widget build(BuildContext context) {
    // Mirrors DockPreview: a single, source-faithful dock, centred.
    return Center(child: BeuiDock(items: _buildItems()));
  }
}

/// The source's inline GitHub mark (`components/app/icons.tsx`), transcribed
/// from its 24x24 `fill-rule: evenodd` path. Painted rather than shipped as an
/// asset, and sized like the source's `h-5 w-5`.
class _GithubMark extends StatelessWidget {
  const _GithubMark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GithubMarkPainter(colors.foreground),
    );
  }
}

class _GithubMarkPainter extends CustomPainter {
  const _GithubMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24.0);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(12, 0.5)
      ..cubicTo(5.65, 0.5, 0.5, 5.65, 0.5, 12.02)
      ..cubicTo(0.5, 17.12, 3.79, 21.45, 8.36, 22.98)
      ..cubicTo(8.94, 23.08, 9.15, 22.73, 9.15, 22.42)
      ..lineTo(9.15, 20.41)
      ..cubicTo(5.95, 21.11, 5.28, 18.87, 5.28, 18.87)
      ..cubicTo(4.76, 17.54, 4.01, 17.19, 4.01, 17.19)
      ..cubicTo(2.97, 16.48, 4.09, 16.5, 4.09, 16.5)
      ..cubicTo(5.24, 16.58, 5.85, 17.68, 5.85, 17.68)
      ..cubicTo(6.87, 19.44, 8.53, 18.93, 9.19, 18.64)
      ..cubicTo(9.29, 17.9, 9.59, 17.39, 9.92, 17.1)
      ..cubicTo(7.37, 16.81, 4.68, 15.82, 4.68, 11.41)
      ..cubicTo(4.68, 10.15, 5.13, 9.12, 5.86, 8.31)
      ..cubicTo(5.74, 8.02, 5.35, 6.85, 5.97, 5.27)
      ..cubicTo(5.97, 5.27, 6.93, 4.96, 9.12, 6.45)
      ..cubicTo(10.03, 6.2, 11.01, 6.07, 11.99, 6.06)
      ..cubicTo(12.96, 6.06, 13.95, 6.19, 14.86, 6.45)
      ..cubicTo(17.05, 4.96, 18.01, 5.27, 18.01, 5.27)
      ..cubicTo(18.63, 6.85, 18.24, 8.02, 18.12, 8.31)
      ..cubicTo(18.86, 9.12, 19.3, 10.15, 19.3, 11.41)
      ..cubicTo(19.3, 15.83, 16.6, 16.81, 14.03, 17.09)
      ..cubicTo(14.45, 17.45, 14.81, 18.16, 14.81, 19.25)
      ..lineTo(14.81, 22.45)
      ..cubicTo(14.81, 22.76, 15.02, 23.12, 15.61, 23.01)
      ..cubicTo(20.18, 21.48, 23.46, 17.15, 23.46, 12.05)
      ..cubicTo(23.5, 5.65, 18.35, 0.5, 12, 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GithubMarkPainter old) => old.color != color;
}

/// The action-swap showcase — replicates beui.dev/components/motion/action-swap:
/// a hero that auto-alternates a blur button ⇄ a roll button, then a row of
/// text / icon-only / CTA buttons per variant (blur, roll, cascade). Tap any
/// button to swap its content.
class _ActionSwapDemo extends StatefulWidget {
  const _ActionSwapDemo();

  @override
  State<_ActionSwapDemo> createState() => _ActionSwapDemoState();
}

class _ActionSwapDemoState extends State<_ActionSwapDemo> {
  // Hero (the /action-swap page preview): blur ⇄ roll button every 2.6s.
  static const _heroBlur = [
    BeuiActionSwapItem(id: 'copy', label: 'Copy link', icon: LucideIcons.copy),
    BeuiActionSwapItem(id: 'copied', label: 'Copied', icon: LucideIcons.check),
  ];
  static const _heroRoll = [
    BeuiActionSwapItem(id: 'send', label: 'Send', icon: LucideIcons.send),
    BeuiActionSwapItem(id: 'sent', label: 'Sent', icon: LucideIcons.sparkles),
  ];

  // Per-variant rows (from the variant preview pages).
  static const _theme = [
    BeuiActionSwapItem(
      id: 'light',
      label: 'Light',
      icon: LucideIcons.sun,
      semanticLabel: 'Use light theme',
    ),
    BeuiActionSwapItem(
      id: 'dark',
      label: 'Dark',
      icon: LucideIcons.moon,
      semanticLabel: 'Use dark theme',
    ),
  ];
  static const _blurText = [
    BeuiActionSwapItem(id: 'copy', label: 'Copy'),
    BeuiActionSwapItem(id: 'copied', label: 'Copied'),
  ];
  static const _blurCta = [
    BeuiActionSwapItem(id: 'copy', label: 'Copy link', icon: LucideIcons.copy),
    BeuiActionSwapItem(id: 'copied', label: 'Copied', icon: LucideIcons.check),
  ];
  static const _rollText = [
    BeuiActionSwapItem(id: 'idle', label: 'Save'),
    BeuiActionSwapItem(id: 'done', label: 'Saved'),
  ];
  static const _rollCta = [
    BeuiActionSwapItem(
      id: 'send',
      label: 'Send invite',
      icon: LucideIcons.send,
    ),
    BeuiActionSwapItem(
      id: 'sent',
      label: 'Invite sent',
      icon: LucideIcons.sparkles,
    ),
  ];
  static const _cascadeCta = [
    BeuiActionSwapItem(id: 'copy', label: 'Copy link', icon: LucideIcons.copy),
    BeuiActionSwapItem(id: 'copied', label: 'Copied!', icon: LucideIcons.check),
  ];

  bool _heroIsRoll = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _heroIsRoll = !_heroIsRoll);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: colors.mutedForeground,
        ),
      ),
    );

    Widget row(
      BeuiActionSwapVariant anim,
      List<BeuiActionSwapItem> text,
      List<BeuiActionSwapItem> cta,
    ) => Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BeuiActionSwapButton(
          items: text,
          animation: anim,
          variant: BeuiButtonVariant.secondary,
        ),
        BeuiActionSwapButton(
          items: _theme,
          animation: anim,
          variant: BeuiButtonVariant.outline,
          size: BeuiButtonSize.icon,
          iconOnly: true,
        ),
        BeuiActionSwapButton(
          items: cta,
          animation: anim,
          variant: BeuiButtonVariant.primary,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        caption('Tap to swap — the preview auto-alternates blur ⇄ roll'),
        SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: beuiEaseOut,
              switchOutCurve: beuiEaseOut,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _heroIsRoll
                  ? const BeuiActionSwapButton(
                      key: ValueKey('roll'),
                      items: _heroRoll,
                      animation: BeuiActionSwapVariant.roll,
                      variant: BeuiButtonVariant.primary,
                    )
                  : const BeuiActionSwapButton(
                      key: ValueKey('blur'),
                      items: _heroBlur,
                      animation: BeuiActionSwapVariant.blur,
                      variant: BeuiButtonVariant.secondary,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        caption('Blur — blurred cross-fade'),
        row(BeuiActionSwapVariant.blur, _blurText, _blurCta),
        const SizedBox(height: 28),
        caption('Roll — old rolls out the top, new rolls up from below'),
        row(BeuiActionSwapVariant.roll, _rollText, _rollCta),
        const SizedBox(height: 28),
        caption('Cascade — per-letter slot roll'),
        const BeuiActionSwapButton(
          items: _cascadeCta,
          animation: BeuiActionSwapVariant.cascade,
          variant: BeuiButtonVariant.primary,
        ),
      ],
    );
  }
}

/// The text-animation showcase — the four previews
/// beui.dev/components/motion/text-animation ships, in the page's own order:
/// `ChromaticTextRevealPreview`, `TextRevealPreview`, `TextShimmerPreview`,
/// `TextCascadePreview`. Each block mirrors its source preview verbatim; the
/// captions stand in for the site's per-primitive section headings.
///
/// Type sizes take the source's `sm:` branch (the ≥640px one), which is what the
/// site renders in the 824px-wide preview band: `text-5xl` = 48px,
/// `tracking-[-0.04em]` = −1.92px at that size.
class _TextAnimationDemo extends StatefulWidget {
  const _TextAnimationDemo();

  @override
  State<_TextAnimationDemo> createState() => _TextAnimationDemoState();
}

class _TextAnimationDemoState extends State<_TextAnimationDemo> {
  static const _phrases = ['Install skills', 'Open settings', 'Ship updates'];

  int _phrase = 0;
  int _replay = 0;
  Timer? _cascadeTimer;

  @override
  void initState() {
    super.initState();
    // Source TextCascadePreview cycles its phrases every 2.4s.
    _cascadeTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (mounted) setState(() => _phrase = (_phrase + 1) % _phrases.length);
    });
  }

  @override
  void dispose() {
    _cascadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: colors.mutedForeground,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ChromaticTextRevealPreview: prefix + cycling words, `text-5xl
        // font-medium tracking-[-0.04em]`, started on mount (startOnView false).
        caption('Dia text animation — a colour edge paints each word in'),
        Center(
          child: BeuiChromaticTextReveal(
            prefix: 'Motion that feels',
            words: const ['natural.', 'intentional.', 'alive.'],
            startOnView: false,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.92,
              color: colors.foreground,
            ),
          ),
        ),
        const SizedBox(height: 48),

        // TextRevealPreview: centred headline + delayed subtitle (`gap-2`), then
        // `gap-8` to the Replay pill.
        caption('Reveal — word by word, with a soft blur'),
        KeyedSubtree(
          key: ValueKey(_replay),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiTextReveal(
                const ['Motion that feels', 'considered.'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  height: 0.95, // leading-[0.95]
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.92, // tracking-[-0.04em]
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 8), // gap-2
              BeuiTextReveal(
                'Word by word, with a soft blur.',
                delay: const Duration(milliseconds: 900),
                stagger: const Duration(milliseconds: 50),
                blur: 6,
                yOffset: 0.2,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.mutedForeground),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32), // gap-8
        Center(child: _ReplayPill(onTap: () => setState(() => _replay++))),
        const SizedBox(height: 48),

        // TextShimmerPreview: `flex flex-col gap-4`, left-aligned inside a
        // centred block.
        caption('Shimmer — gradient sweep'),
        Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiTextShimmer(
                'Loading projects…',
                style: TextStyle(
                  fontSize: 30, // text-3xl
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 16), // gap-4
              BeuiTextShimmer(
                'Faster shimmer',
                duration: const Duration(milliseconds: 1500),
                style: TextStyle(fontSize: 14, color: colors.foreground),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        // TextCascadePreview: one centred `text-lg font-medium` line, cycling.
        caption('Cascade — per-letter slot roll (cycles)'),
        Center(
          child: BeuiTextCascade(
            _phrases[_phrase],
            style: TextStyle(
              fontSize: 18, // text-lg
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}

/// The Replay control from `TextRevealPreview` — preview chrome, not a beUI
/// component: `h-9 rounded-full border border-border bg-card px-4 text-xs
/// font-medium`.
class _ReplayPill extends StatelessWidget {
  const _ReplayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 36, // h-9
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(18), // rounded-full
          ),
          // widthFactor: 1 shrink-wraps the pill to its label; without it the
          // Container's alignment would expand to the row's full width.
          child: Center(
            widthFactor: 1,
            child: Text(
              'Replay',
              style: TextStyle(
                fontSize: 12, // text-xs
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
