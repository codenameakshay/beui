import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

class _Host extends StatefulWidget {
  const _Host({required this.initial, this.reduce = false});
  final String initial;
  final bool reduce;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String _text = widget.initial;

  void set(String t) => setState(() => _text = t);

  @override
  Widget build(BuildContext context) => beuiTestApp(
    DefaultTextStyle(
      style: const TextStyle(fontSize: 28),
      child: BeuiTextCascade(_text),
    ),
    reduce: widget.reduce,
  );
}

/// Hosts a cascade given only a partial style, so the ambient [DefaultTextStyle]
/// still supplies the line height.
class _SlotHost extends StatefulWidget {
  const _SlotHost();

  @override
  State<_SlotHost> createState() => _SlotHostState();
}

class _SlotHostState extends State<_SlotHost> {
  String _text = 'Install skills';

  void set(String t) => setState(() => _text = t);

  @override
  Widget build(BuildContext context) => BeuiTextCascade(
    _text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
  );
}

/// Counts the number of single-character [Text] widgets currently rendered.
int _letterCount(WidgetTester tester) {
  var n = 0;
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    if ((t.data ?? '').length == 1) n++;
  }
  return n;
}

void main() {
  testWidgets('at rest the cascade renders the whole string, not per-letter', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: 'Hello'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    expect(_letterCount(tester), 0, reason: 'no per-letter split at rest');
  });

  testWidgets('changing the text rolls letter-by-letter', (tester) async {
    await tester.pumpWidget(const _Host(initial: 'Hi'));
    await tester.pumpAndSettle();

    tester.state<_HostState>(find.byType(_Host)).set('Yo');
    await tester.pump(); // start transition
    await tester.pump(const Duration(milliseconds: 60));

    // Mid-transition both the old and new letters exist as individual glyphs.
    expect(
      _letterCount(tester),
      greaterThan(0),
      reason: 'letters animate individually during the roll',
    );
    expect(find.text('Y'), findsOneWidget);
    expect(find.text('o'), findsOneWidget);
    // Old letters still present (rolling out).
    expect(find.text('H'), findsOneWidget);

    // After settling it collapses back to the whole new string.
    await tester.pumpAndSettle();
    expect(find.text('Yo'), findsOneWidget);
    expect(_letterCount(tester), 0);
  });

  testWidgets('letters translate and blur while rolling', (tester) async {
    await tester.pumpWidget(const _Host(initial: 'AB'));
    await tester.pumpAndSettle();

    tester.state<_HostState>(find.byType(_Host)).set('CD');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // Some letter is mid-roll: a non-zero vertical translate is present.
    final translated = tester
        .widgetList<Transform>(find.byType(Transform))
        .any((t) => t.transform.getTranslation().y.abs() > 0.5);
    expect(translated, isTrue, reason: 'letters roll vertically');

    await tester.pumpAndSettle();
  });

  testWidgets('the rolling slot keeps the resting height (no layout jump)', (
    tester,
  ) async {
    // A partial style (size + weight only) inherits the ambient `height`, which
    // is what Text paints with. The rolling slot is measured separately, so if
    // it ignored the ambient style the line would grow mid-roll and shove the
    // surrounding layout — seen on beui.dev/components/motion/text-animation as
    // a 5px jump of the whole column on every cascade.
    await tester.pumpWidget(
      beuiTestApp(
        const DefaultTextStyle(
          style: TextStyle(fontSize: 14, height: 1.43),
          child: _SlotHost(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rest = tester.getSize(find.byType(BeuiTextCascade));

    tester.state<_SlotHostState>(find.byType(_SlotHost)).set('Open settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.getSize(find.byType(BeuiTextCascade)).height,
      moreOrLessEquals(rest.height, epsilon: 0.5),
      reason: 'the slot height must not change when the roll starts',
    );

    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(BeuiTextCascade)).height,
      moreOrLessEquals(rest.height, epsilon: 0.5),
    );
  });

  testWidgets('reduced motion shows plain text with no per-letter roll', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: 'Hi', reduce: true));
    await tester.pumpAndSettle();

    tester.state<_HostState>(find.byType(_Host)).set('Yo');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // No per-letter split under reduced motion — the whole string swaps.
    expect(_letterCount(tester), 0);
    expect(find.text('Yo'), findsOneWidget);
  });
}
