import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCitations] — mirrors the source preview: progressive
/// source append with inline markers, then a Replay control.
Widget citationsDemo(BuildContext context) => const _CitationsDemo();

const _items = <BeuiCitationItem>[
  BeuiCitationItem(
    id: 'motion',
    title: Text('Motion documentation'),
    domain: Text('motion.dev'),
    url: 'https://motion.dev/docs/react',
  ),
  BeuiCitationItem(
    id: 'wai',
    title: Text('WAI accessibility patterns'),
    domain: Text('w3.org'),
    url: 'https://www.w3.org/WAI/ARIA/apg/',
  ),
  BeuiCitationItem(
    id: 'react',
    title: Text('React documentation'),
    domain: Text('react.dev'),
    url: 'https://react.dev/learn',
  ),
];

class _CitationsDemo extends StatefulWidget {
  const _CitationsDemo();

  @override
  State<_CitationsDemo> createState() => _CitationsDemoState();
}

class _CitationsDemoState extends State<_CitationsDemo> {
  int _run = 0;
  int _visible = 0;
  final List<Timer> _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    // Schedule after first frame so MediaQuery is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _armProgression());
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _armProgression() {
    _cancelTimers();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      setState(() => _visible = _items.length);
      return;
    }
    setState(() => _visible = 0);
    for (var i = 0; i < _items.length; i++) {
      _timers.add(
        Timer(Duration(milliseconds: 500 + i * 700), () {
          if (!mounted) return;
          setState(() => _visible = i + 1);
        }),
      );
    }
  }

  void _replay() {
    setState(() {
      _run += 1;
      _visible = 0;
    });
    _armProgression();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final shown = _items.take(_visible).toList(growable: false);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512), // max-w-lg
        child: SizedBox(
          height: 410,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: KeyedSubtree(
                  key: ValueKey<int>(_run),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            height: 24 / 14, // leading-6
                            letterSpacing: 0, // Tailwind tracking-normal
                            color: colors.foreground.withValues(alpha: 0.9),
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  'Use layout-aware motion for newly appended results ',
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: BeuiCitation(
                                citationId: 'motion',
                                index: 1,
                                idPrefix: 'preview-source',
                              ),
                            ),
                            const TextSpan(
                              text:
                                  ' and preserve accessible disclosure behavior ',
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: BeuiCitation(
                                citationId: 'wai',
                                index: 2,
                                idPrefix: 'preview-source',
                              ),
                            ),
                            const TextSpan(text: ' as the list grows.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16), // space-y-4
                      BeuiCitations(
                        idPrefix: 'preview-source',
                        citations: shown,
                        defaultOpen: true,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: TextButton(
                  onPressed: _replay,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    // Desktop `adaptivePlatformDensity` is compact (-2,-2),
                    // which eats 4px of the source's 24px button height.
                    visualDensity: VisualDensity.standard,
                    foregroundColor: colors.foreground,
                  ),
                  // Source: inline-flex items-center gap-1.5 px-2 py-1 text-xs.
                  // `TextButton.icon` hardcodes an 8px gap, so build the row.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.rotate_ccw,
                        size: 12,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: 6), // gap-1.5
                      Text(
                        'Replay',
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12, // text-xs
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
