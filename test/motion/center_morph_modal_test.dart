import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _panel = ValueKey<String>('beui_center_morph_modal_panel');

class _Host extends StatefulWidget {
  const _Host({
    this.dismissible = true,
    this.showCloseButton = true,
    this.disableAnimations = false,
  });

  final bool dismissible;
  final bool showCloseButton;
  final bool disableAnimations;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool open = false;
  final List<bool> changes = <bool>[];

  void show() => setState(() => open = true);
  void hide() => setState(() => open = false);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      builder: (context, child) {
        if (!widget.disableAnimations) return child!;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: Scaffold(
        body: BeuiCenterMorphModal(
          open: open,
          dismissible: widget.dismissible,
          showCloseButton: widget.showCloseButton,
          label: 'Demo modal',
          onOpenChange: (v) {
            changes.add(v);
            setState(() => open = v);
          },
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text('MODAL BODY'),
          ),
        ),
      ),
    );
  }
}

void main() {
  _HostState host(WidgetTester t) => t.state<_HostState>(find.byType(_Host));

  testWidgets('open shows content', (tester) async {
    await tester.pumpWidget(const _Host());
    expect(find.text('MODAL BODY'), findsNothing);

    host(tester).show();
    await tester.pumpAndSettle();
    expect(find.text('MODAL BODY'), findsOneWidget);
    expect(find.byKey(_panel), findsOneWidget);
  });

  testWidgets('unfold runs the source 430ms envelope', (tester) async {
    // CENTER_UNFOLD_TRANSITION is `{ duration: 0.43 }`. A frame-sampled screen
    // capture cannot resolve this (Flutter web paints far fewer frames per
    // wall-clock second than the DOM reference), so pin it here instead.
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pump(); // schedule the enter
    await tester.pump(const Duration(milliseconds: 420));
    expect(
      tester.binding.transientCallbackCount,
      greaterThan(0),
      reason: 'still unfolding at 420ms — the envelope must not collapse',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsOneWidget);
  });

  testWidgets('onOpenChange(false) on barrier dismiss', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    // Panel is centered; tap near the corner for the barrier.
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(host(tester).changes, contains(false));
    await tester.pumpAndSettle();
    expect(find.text('MODAL BODY'), findsNothing);
  });

  testWidgets('onOpenChange(false) on Esc', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(host(tester).changes.last, isFalse);
  });

  testWidgets('close button dismisses', (tester) async {
    await tester.pumpWidget(const _Host());
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();
    expect(host(tester).changes.last, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('MODAL BODY'), findsNothing);
  });

  testWidgets('non-dismissible ignores barrier taps', (tester) async {
    await tester.pumpWidget(const _Host(dismissible: false));
    host(tester).show();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(host(tester).changes, isEmpty);
    expect(find.text('MODAL BODY'), findsOneWidget);
  });

  testWidgets('reduced motion still opens and closes', (tester) async {
    await tester.pumpWidget(const _Host(disableAnimations: true));
    host(tester).show();
    await tester.pumpAndSettle();
    expect(find.text('MODAL BODY'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('MODAL BODY'), findsNothing);
    expect(host(tester).changes.last, isFalse);
  });

  testWidgets('hides close button when showCloseButton is false', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(showCloseButton: false));
    host(tester).show();
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.x), findsNothing);
    expect(find.text('MODAL BODY'), findsOneWidget);
  });
}
