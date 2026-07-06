import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiDynamicIsland] — tap the chips to morph between
/// live-activity views.
Widget dynamicIslandDemo(BuildContext context) => const _IslandDemo();

class _IslandDemo extends StatefulWidget {
  const _IslandDemo();

  @override
  State<_IslandDemo> createState() => _IslandDemoState();
}

class _IslandDemoState extends State<_IslandDemo> {
  String? _view;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      children: [
        const SizedBox(height: 24),
        BeuiDynamicIsland(
          view: _view,
          compact: const Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(LucideIcons.mic, size: 12, color: Color(0xFFF87171)),
              Text('Recording'),
            ],
          ),
          views: [
            BeuiDynamicIslandView(
              id: 'timer',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  const Icon(LucideIcons.timer, size: 20),
                  const Text(
                    '12:41',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'Focus session',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.background.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            BeuiDynamicIslandView(
              id: 'call',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF10B981),
                    child: Icon(LucideIcons.phone, size: 14),
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ada Lovelace', style: TextStyle(fontSize: 13)),
                      Text(
                        'mobile',
                        style: TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    LucideIcons.phone_off,
                    size: 18,
                    color: Color(0xFFF87171),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        Wrap(
          spacing: 12,
          children: [
            BeuiButton(
              onPressed: () => setState(() => _view = null),
              child: const Text('Pill'),
            ),
            BeuiButton(
              onPressed: () => setState(() => _view = 'timer'),
              child: const Text('Timer'),
            ),
            BeuiButton(
              onPressed: () => setState(() => _view = 'call'),
              child: const Text('Call'),
            ),
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}
