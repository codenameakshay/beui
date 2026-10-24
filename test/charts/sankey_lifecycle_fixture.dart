import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(home: _Fixture()));

class _Fixture extends StatefulWidget {
  const _Fixture();
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  bool includeB = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR): () =>
            setState(() => includeB = false),
        const SingleActivator(LogicalKeyboardKey.keyI): () =>
            setState(() => includeB = true),
      },
      child: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: 300,
            child: Column(
              children: [
                TextButton(onPressed: () {}, child: const Text('Before')),
                if (Uri.base.queryParameters['scenario'] == 'offscreen')
                  const SizedBox(height: 800),
                BeuiSankeyChart(
                  nodes: const [
                    BeuiSankeyNode(id: 'a', label: 'A'),
                    BeuiSankeyNode(id: 'b', label: 'B'),
                    BeuiSankeyNode(id: 'c', label: 'C'),
                  ],
                  links: [
                    const BeuiSankeyLink(source: 'a', target: 'c', value: 30),
                    if (includeB)
                      const BeuiSankeyLink(source: 'b', target: 'c', value: 70),
                  ],
                ),
                TextButton(onPressed: () {}, child: const Text('Outside')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
