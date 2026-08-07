import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  bool? open,
  ValueChanged<bool>? onOpenChange,
  bool reduce = false,
}) {
  Widget body = Center(
    child: BeuiPopover(
      open: open,
      onOpenChange: onOpenChange,
      content: const Text('Panel body'),
      child: const SizedBox(
        width: 120,
        height: 44,
        child: Center(child: Text('Trigger')),
      ),
    ),
  );
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

/// A controlled host whose `open` can be toggled from the test body, so a
/// single widget lifetime covers both the enter and the exit.
class _ToggleHost extends StatefulWidget {
  const _ToggleHost();

  @override
  State<_ToggleHost> createState() => _ToggleHostState();
}

class _ToggleHostState extends State<_ToggleHost> {
  bool open = false;

  void show() => setState(() => open = true);
  void hide() => setState(() => open = false);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(
      body: Center(
        child: BeuiPopover(
          open: open,
          onOpenChange: (v) => setState(() => open = v),
          content: const Text('Panel body'),
          child: const SizedBox(
            width: 120,
            height: 44,
            child: Center(child: Text('Trigger')),
          ),
        ),
      ),
    ),
  );
}

/// Settles at 1ms granularity and returns the fake-clock time it took.
///
/// `pumpAndSettle`'s default 100ms step is far too coarse to tell a 210ms exit
/// from a 300ms entrance — both round to the same number of pumps.
Future<int> _settleMs(WidgetTester tester) async {
  final start = tester.binding.clock.now();
  await tester.pumpAndSettle(const Duration(milliseconds: 1));
  return tester.binding.clock.now().difference(start).inMilliseconds;
}

void main() {
  testWidgets('the close spring settles faster than the open spring', (
    tester,
  ) async {
    // `GOO_OPEN_SPRING` is Framer `{visualDuration: 0.3, bounce: 0.15}` and
    // `GOO_CLOSE_SPRING` is `{visualDuration: 0.21, bounce: 0.15}` — same
    // bounce, a deliberately quicker exit ("exits faster than entrances"). Same
    // bounce means the two settle times stand in the same ratio as their visual
    // durations, so the port is checked against 0.21/0.3 = 0.7 rather than
    // against two hand-copied millisecond figures.
    final host = _ToggleHost.new;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    tester.state<_ToggleHostState>(find.byType(_ToggleHost)).show();
    final open = await _settleMs(tester);

    tester.state<_ToggleHostState>(find.byType(_ToggleHost)).hide();
    final close = await _settleMs(tester);

    expect(
      open,
      greaterThan(100),
      reason:
          'the goo must actually spring — a 0ms settle means the '
          'SingleMotionBuilder was rebuilt from scratch and started at its '
          'target instead of animating to it',
    );
    expect(
      close,
      lessThan(open),
      reason: 'GOO_CLOSE_SPRING must settle before GOO_OPEN_SPRING',
    );
    expect(
      close / open,
      closeTo(0.21 / 0.3, 0.1),
      reason: 'the exit/entrance ratio must track the source visualDurations',
    );
  });

  testWidgets('tap toggles open via onOpenChange (uncontrolled)', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(_app(onOpenChange: changes.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(changes.last, isTrue);
    expect(find.text('Panel body'), findsWidgets);
  });

  // The Esc binding and the tap-outside region used to be mounted only while
  // the popover was open, which is what forced the goo to remount on every
  // toggle. They are permanent now and gated by `_open` instead, so both
  // dismiss paths are pinned here.
  testWidgets('esc dismisses the open panel', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(_app(onOpenChange: changes.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(changes.last, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(changes.last, isFalse);
  });

  testWidgets('a tap outside dismisses the open panel', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(_app(onOpenChange: changes.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(changes.last, isTrue);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(changes.last, isFalse);
  });

  testWidgets('controlled open renders the panel content', (tester) async {
    await tester.pumpWidget(_app(open: true));
    await tester.pumpAndSettle();
    expect(find.text('Panel body'), findsWidgets);
  });

  testWidgets('reduced motion drops the goo ImageFiltered layer', (
    tester,
  ) async {
    await tester.pumpWidget(_app(open: true, reduce: true));
    await tester.pumpAndSettle();
    // The goo filter is skipped under reduced motion.
    expect(
      find.descendant(
        of: find.byType(BeuiPopover),
        matching: find.byType(ImageFiltered),
      ),
      findsNothing,
    );
  });

  testWidgets('open-state golden', (tester) async {
    await tester.pumpWidget(_app(open: true));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiPopover),
      matchesGoldenFile('goldens/beui_popover.png'),
    );
  });
}
