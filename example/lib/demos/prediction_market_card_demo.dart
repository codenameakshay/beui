import 'package:flutter/material.dart';

import 'package:beui/beui.dart';

/// Gallery route for [BeuiPredictionMarketCard].
Widget predictionMarketCardDemo(BuildContext context) =>
    const _PredictionMarketCardDemo();

class _PredictionMarketCardDemo extends StatefulWidget {
  const _PredictionMarketCardDemo();

  @override
  State<_PredictionMarketCardDemo> createState() =>
      _PredictionMarketCardDemoState();
}

class _PredictionMarketCardDemoState extends State<_PredictionMarketCardDemo> {
  bool _updated = false;
  final Set<String> _saved = {};

  static const _markets = <_MarketData>[
    _MarketData(
      id: 'basketball',
      title: 'Boston Celtics vs. Los Angeles Lakers',
      category: 'Basketball',
      status: 'Sunday · 7:30 PM',
      volume: r'$2.4M',
      history: [12, 18, 15, 26, 20, 32, 29, 38, 34, 48, 43, 58],
      colors: [Color(0xff16784b), Color(0xffd6a82f)],
      labels: ['Celtics', 'Lakers'],
      probabilities: [.51, .49],
      next: [.56, .44],
    ),
    _MarketData(
      id: 'baseball',
      title: 'Tampa Bay Rays vs. Atlanta Braves',
      category: 'MLB',
      status: 'Mid 6th',
      volume: r'$458K',
      history: [8, 12, 10, 19, 15, 28, 23, 34, 30, 40, 36, 45],
      colors: [Color(0xff4584c3), Color(0xffb7475b)],
      labels: ['Rays', 'Braves'],
      probabilities: [.46, .54],
      next: [.52, .48],
      live: true,
    ),
    _MarketData(
      id: 'rates',
      title: 'Where will interest rates land by the end of the year?',
      category: 'Economics',
      status: 'Dec 31',
      volume: r'$347K',
      history: [15, 11, 17, 14, 24, 21, 30, 25, 32, 29, 39, 42],
      colors: [Color(0xff16784b), Color(0xff4584c3)],
      labels: ['Below 3.5%', 'Above 4.0%'],
      probabilities: [.68, .23],
      next: [.72, .18],
      rates: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'On the radar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text('Demo markets · simulated prices'),
                      ],
                    ),
                  ),
                  BeuiButton(
                    variant: BeuiButtonVariant.secondary,
                    size: BeuiButtonSize.sm,
                    onPressed: () => setState(() => _updated = !_updated),
                    child: const Text('Update odds'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 640 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - 16 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final market in _markets)
                        SizedBox(
                          width: width,
                          child: BeuiPredictionMarketCard(
                            title: market.title,
                            category: market.category,
                            status: market.status,
                            live: market.live,
                            volume: market.volume,
                            volumeHistory: market.history,
                            bookmarked: _saved.contains(market.id),
                            onBookmarkChange: (saved) => setState(() {
                              if (saved) {
                                _saved.add(market.id);
                              } else {
                                _saved.remove(market.id);
                              }
                            }),
                            icon: _MarketMark(
                              color: market.colors.first,
                              rates: market.rates,
                            ),
                            outcomes: [
                              for (var i = 0; i < market.labels.length; i++)
                                BeuiPredictionMarketCardOutcome(
                                  id: '${market.id}-$i',
                                  label: market.labels[i],
                                  probability: _updated
                                      ? market.next[i]
                                      : market.probabilities[i],
                                  color: market.colors[i],
                                  icon: market.rates
                                      ? null
                                      : _MarketMark(
                                          color: market.colors[i],
                                          compact: true,
                                        ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketData {
  const _MarketData({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.volume,
    required this.history,
    required this.colors,
    required this.labels,
    required this.probabilities,
    required this.next,
    this.live = false,
    this.rates = false,
  });

  final String id;
  final String title;
  final String category;
  final String status;
  final String volume;
  final List<double> history;
  final List<Color> colors;
  final List<String> labels;
  final List<double> probabilities;
  final List<double> next;
  final bool live;
  final bool rates;
}

class _MarketMark extends StatelessWidget {
  const _MarketMark({
    required this.color,
    this.compact = false,
    this.rates = false,
  });

  final Color color;
  final bool compact;
  final bool rates;

  @override
  Widget build(BuildContext context) => Container(
    width: compact ? 28 : 44,
    height: compact ? 28 : 44,
    alignment: Alignment.center,
    color: rates ? Colors.white : color.withValues(alpha: .14),
    child: rates
        ? Icon(LucideIcons.landmark, size: compact ? 16 : 24, color: color)
        : Text(
            compact ? '•' : '◎',
            style: TextStyle(
              color: color,
              fontSize: compact ? 18 : 27,
              fontWeight: FontWeight.w700,
            ),
          ),
  );
}
