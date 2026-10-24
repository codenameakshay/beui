import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'explorer/capture_probe.dart';
import 'explorer/explorer_app.dart';
import 'demos/prediction_market_card_demo.dart';

void main() => runApp(const BlockControlProbe());

/// Standalone behavioral fixture. It is not a reference preview wrapper.
class BlockControlProbe extends StatefulWidget {
  const BlockControlProbe({super.key});

  @override
  State<BlockControlProbe> createState() => _BlockControlProbeState();
}

class _BlockControlProbeState extends State<BlockControlProbe> {
  int _actions = 0;
  int _disabledCallbacks = 0;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Uri.base.queryParameters['theme'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    final colors = BeuiColors.of(BeuiColorTheme.defaultMono, brightness);
    return MaterialApp(
      theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, brightness),
      home: Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: SizedBox(
            width: 592,
            child: CaptureProbe(
              enabled: true,
              background: colors.background,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Control contract fixture. Not a source preview.'),
                  const SizedBox(height: 32),
                  BeuiCardFolder(
                    title: 'Enabled fixture',
                    cardNumber: '3745698740960806',
                    expiry: '08/29',
                    cvv: '123',
                    card: Container(
                      color: colors.muted,
                      alignment: Alignment.center,
                      child: const Text('Enabled card artwork fixture'),
                    ),
                    onDetailsVisibleChange: (value) =>
                        setState(() => _revealed = value),
                    onAction: () => setState(() => _actions++),
                  ),
                  const SizedBox(height: 32),
                  BeuiCardFolder(
                    title: 'Disabled fixture',
                    cardNumber: '3745698740960806',
                    expiry: '08/29',
                    cvv: '123',
                    disabled: true,
                    card: Container(
                      color: colors.muted,
                      alignment: Alignment.center,
                      child: const Text('Disabled card artwork fixture'),
                    ),
                    onDetailsVisibleChange: (_) =>
                        setState(() => _disabledCallbacks++),
                    onOpenChange: (_) => setState(() => _disabledCallbacks++),
                    onAction: () => setState(() => _disabledCallbacks++),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Actions: $_actions. Revealed: $_revealed. Disabled callbacks: $_disabledCallbacks.',
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Expected missing SVG keeps an empty white slot: '),
                      SizedBox.square(
                        dimension: 48,
                        child: MarketArtwork(
                          url: 'http://127.0.0.1:8108/block-probe/missing.svg',
                          rates: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
