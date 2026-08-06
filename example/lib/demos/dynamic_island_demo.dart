import 'dart:async';
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiDynamicIsland] — mirrors
/// `dynamic-island.preview.tsx`: a `9:41` compact pill that morphs into an
/// incoming call, a counting timer, or a now-playing card.
Widget dynamicIslandDemo(BuildContext context) => const _IslandDemo();

class _IslandDemo extends StatefulWidget {
  const _IslandDemo();

  @override
  State<_IslandDemo> createState() => _IslandDemoState();
}

class _IslandDemoState extends State<_IslandDemo> {
  String? _view;
  int _seconds = 154;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _show(String? view) {
    _tick?.cancel();
    setState(() => _view = view);
    if (view == 'timer') {
      setState(() => _seconds = 154);
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds = _seconds > 0 ? _seconds - 1 : 0);
      });
    }
  }

  static String _clock(num total) {
    final t = total.round();
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    // The island paints on a light shell, so its content reads on `background`.
    final onShell = colors.background;

    Widget caption(String text) => Text(
      text,
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 0.8,
        color: onShell.withValues(alpha: 0.6),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16, // gap-4
      children: [
        // `h-32 items-start justify-center pt-2` — the island stays pinned at
        // the top like under a notch and unfurls into reserved space.
        SizedBox(
          height: 128,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: BeuiDynamicIsland(
                view: _view,
                compact: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text('9:41'),
                  ],
                ),
                views: [
                  BeuiDynamicIslandView(
                    id: 'call',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16, // gap-4
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            caption('INCOMING CALL'),
                            const Text(
                              'Saurabh',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 8,
                          children: [
                            _CallButton(
                              icon: LucideIcons.phone_off,
                              color: colors.destructive,
                              label: 'Decline',
                              onPressed: () => _show(null),
                            ),
                            _CallButton(
                              icon: LucideIcons.phone,
                              color: colors.success,
                              label: 'Accept',
                              onPressed: () => _show(null),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  BeuiDynamicIslandView(
                    id: 'timer',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 12, // gap-3
                      children: [
                        Icon(
                          LucideIcons.timer,
                          size: 16,
                          color: colors.warning,
                        ),
                        caption('TIMER'),
                        Text(
                          _clock(_seconds),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  BeuiDynamicIslandView(
                    id: 'music',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 12,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: onShell.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.music, size: 14),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Midnight City',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'M83',
                              style: TextStyle(
                                fontSize: 10,
                                color: onShell.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        _EqBars(color: colors.success),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 8, // gap-2
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BeuiButton(
              size: BeuiButtonSize.sm,
              variant: BeuiButtonVariant.secondary,
              onPressed: () => _show('call'),
              child: const Text('Call'),
            ),
            BeuiButton(
              size: BeuiButtonSize.sm,
              variant: BeuiButtonVariant.secondary,
              onPressed: () => _show('timer'),
              child: const Text('Timer'),
            ),
            BeuiButton(
              size: BeuiButtonSize.sm,
              variant: BeuiButtonVariant.secondary,
              onPressed: () => _show('music'),
              child: const Text('Music'),
            ),
            BeuiButton(
              size: BeuiButtonSize.sm,
              variant: BeuiButtonVariant.ghost,
              onPressed: () => _show(null),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    ),
  );
}

/// Four bars pulsing on a staggered 1.1s loop (source `EqBars`).
class _EqBars extends StatefulWidget {
  const _EqBars({required this.color});

  final Color color;

  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars> with SingleTickerProviderStateMixin {
  static const _delays = [0.0, 0.18, 0.09, 0.27];
  static const _keys = [0.4, 1.0, 0.55, 0.9, 0.4];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _scaleAt(double t) {
    final pos = (t * (_keys.length - 1)).clamp(0.0, (_keys.length - 1) * 1.0);
    final i = pos.floor().clamp(0, _keys.length - 2);
    return Curves.easeInOut.transform(pos - i) * (_keys[i + 1] - _keys[i]) +
        _keys[i];
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 16, // h-4
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 2, // gap-0.5
        children: [
          for (final delay in _delays)
            Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: Container(
                width: 2,
                height: 16 * _scaleAt((_c.value + delay) % 1.0),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
