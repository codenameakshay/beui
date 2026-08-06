import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiAnimatedToastStack] — a faithful port of the source
/// `animated-toast-stack.preview.tsx`: a `flex min-h-72 flex-col items-center
/// justify-center gap-6` column holding the copy block, the Promise/Success/
/// Error/Clear pill buttons, and the six position pills. The stack itself
/// renders "fixed" over the demo area at the selected edge.
Widget animatedToastStackDemo(BuildContext context) =>
    const _AnimatedToastStackDemo();

class _AnimatedToastStackDemo extends StatefulWidget {
  const _AnimatedToastStackDemo();

  @override
  State<_AnimatedToastStackDemo> createState() =>
      _AnimatedToastStackDemoState();
}

class _AnimatedToastStackDemoState extends State<_AnimatedToastStackDemo> {
  // Source: `useAnimatedToastStack({ defaultDuration: 3600, limit: 5 })`.
  final BeuiToastController _toasts = BeuiToastController(
    defaultDuration: const Duration(milliseconds: 3600),
    limit: 5,
  );

  BeuiToastPosition _position = BeuiToastPosition.bottomRight;

  static const _positions = <(BeuiToastPosition, String)>[
    (BeuiToastPosition.topLeft, 'top-left'),
    (BeuiToastPosition.topCenter, 'top-center'),
    (BeuiToastPosition.topRight, 'top-right'),
    (BeuiToastPosition.bottomLeft, 'bottom-left'),
    (BeuiToastPosition.bottomCenter, 'bottom-center'),
    (BeuiToastPosition.bottomRight, 'bottom-right'),
  ];

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  // EXAMPLES[0] — a promise toast that patches itself to success after 1.8s.
  void _promise() {
    final id = _toasts.show(
      title: 'Publishing component',
      description: 'Bundling source, preview, and registry metadata.',
      status: BeuiToastStatus.loading,
      duration: Duration.zero, // sticky while loading
    );
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      _toasts.update(
        id,
        title: 'Publish complete',
        description: 'Toast updated in-place from loading to success.',
        status: BeuiToastStatus.success,
        duration: const Duration(milliseconds: 3200),
      );
    });
  }

  void _success() => _toasts.show(
    title: 'Component published',
    description: 'Registry endpoint and raw source are available.',
    status: BeuiToastStatus.success,
  );

  void _error() => _toasts.show(
    title: 'Snapshot failed',
    description: 'Retry after the browser target settles.',
    status: BeuiToastStatus.error,
  );

  void _move(BeuiToastPosition next, String label) {
    setState(() => _position = next);
    _toasts.show(
      title: 'Position changed',
      description: 'New toasts open from $label.',
      status: BeuiToastStatus.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Stack(
      children: [
        // `flex min-h-72 w-full flex-col items-center justify-center gap-6`
        Positioned.fill(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 288),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Copy block: `flex flex-col items-center gap-2 text-center`.
                  Text(
                    'Open a real toast',
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 384, // max-w-sm
                    child: Text(
                      'Toasts render fixed on the screen. Change position to '
                      'open a toast from that edge.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 20 / 12, // leading-5
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24), // gap-6
                  // Action buttons: `flex flex-wrap justify-center gap-2`.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _PillButton(
                        icon: LucideIcons.loader_circle,
                        label: 'Promise',
                        onPressed: _promise,
                      ),
                      _PillButton(
                        icon: LucideIcons.check,
                        label: 'Success',
                        onPressed: _success,
                      ),
                      _PillButton(
                        icon: LucideIcons.x,
                        label: 'Error',
                        onPressed: _error,
                      ),
                      _PillButton(label: 'Clear', onPressed: _toasts.clear),
                    ],
                  ),
                  const SizedBox(height: 24), // gap-6
                  // Position pills: `flex flex-wrap justify-center gap-1.5`.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final (value, label) in _positions)
                        _PositionPill(
                          label: label,
                          selected: _position == value,
                          onPressed: () => _move(value, label),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // The "fixed" stack — POSITION_CLASS insets: top-4 / bottom-6 / x-4.
        Positioned(
          top: _position.isBottom ? null : 16,
          bottom: _position.isBottom ? 24 : null,
          left: 16,
          right: 16,
          child: Align(
            alignment: switch (_position) {
              BeuiToastPosition.topLeft ||
              BeuiToastPosition.bottomLeft => Alignment.centerLeft,
              BeuiToastPosition.topCenter ||
              BeuiToastPosition.bottomCenter => Alignment.center,
              BeuiToastPosition.topRight ||
              BeuiToastPosition.bottomRight => Alignment.centerRight,
            },
            child: ListenableBuilder(
              listenable: _toasts,
              builder: (context, _) => BeuiAnimatedToastStack(
                toasts: _toasts.toasts,
                onDismiss: _toasts.dismiss,
                position: _position,
                maxVisible: 4,
                icons: const {
                  BeuiToastStatus.neutral: Icon(LucideIcons.sparkles, size: 14),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `inline-flex h-9 items-center gap-2 rounded-full border border-border
/// bg-card px-4 text-xs font-medium` — or, with no [icon], the borderless
/// muted "Clear" variant.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed, this.icon});

  final IconData? icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final bare = icon == null;
    final fg = bare ? colors.mutedForeground : colors.foreground;
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 36, // h-9
          padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
          decoration: BoxDecoration(
            color: bare ? null : colors.card,
            border: bare ? null : Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(18), // rounded-full
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg), // h-3.5 w-3.5
                const SizedBox(width: 8), // gap-2
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `rounded-full px-2.5 py-1 text-[11px] font-medium`, selected =
/// `bg-foreground text-background`, else `bg-foreground/[0.04]
/// text-muted-foreground`.
class _PositionPill extends StatelessWidget {
  const _PositionPill({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? colors.foreground
                : colors.foreground.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: selected ? colors.background : colors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
