/// Shared "hidden content + live-edge follow" contract exercised identically
/// by `BeuiCodeBlock` and `BeuiFileDiff`: a capped viewport announces how
/// much content it is hiding, one that fits says nothing, and — while
/// streaming — scrolling away from the live edge stops the auto-follow and
/// offers a "Jump to latest" pill back to it.
library;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

/// Runs the three-part contract against a host built by [build].
///
/// [build] renders the fully-wrapped host widget (theme, `Scaffold`, sizing)
/// for [lineCount] lines of content at the given streaming status. [rootType]
/// scopes the vertical scrollable search to the component under test.
/// [fittingLineCount] must render with no hidden content;
/// [overflowingLineCount] and [growLineCount] must overflow the capped
/// viewport (the latter strictly more than the former, to exercise content
/// arriving while the reader has scrolled away).
Future<void> runFollowContract(
  WidgetTester tester, {
  required Widget Function({required int lineCount, required bool streaming})
  build,
  required Type rootType,
  int fittingLineCount = 2,
  int overflowingLineCount = 40,
  int growLineCount = 60,
}) async {
  // A capped viewport says how much it is hiding.
  await tester.pumpWidget(
    build(lineCount: overflowingLineCount, streaming: false),
  );
  await tester.pumpAndSettle();
  expect(find.textContaining('more lines'), findsOneWidget);

  // Content that fits says nothing.
  await tester.pumpWidget(build(lineCount: fittingLineCount, streaming: false));
  await tester.pumpAndSettle();
  expect(find.textContaining('more lines'), findsNothing);

  // Scrolling away from the live edge stops the follow and offers a way back.
  await tester.pumpWidget(
    build(lineCount: overflowingLineCount, streaming: true),
  );
  // The streaming spinner repeats forever, so settle is never an option here
  // — drive the follow's 220ms frame by frame instead.
  await pumpFrames(tester, 20);
  expect(find.text('Jump to latest'), findsNothing);

  final controller = tester
      .widget<SingleChildScrollView>(
        find
            .descendant(
              of: find.byType(rootType),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is SingleChildScrollView &&
                    w.scrollDirection == Axis.vertical &&
                    w.controller != null,
              ),
            )
            .first,
      )
      .controller!;

  // The reader scrolls back to re-read something.
  controller.jumpTo(controller.position.maxScrollExtent - 120);
  await pumpFrames(tester, 20);
  expect(find.text('Jump to latest'), findsOneWidget);
  final pinnedAt = controller.offset;

  // More content arrives; the viewport stays where the reader put it.
  await tester.pumpWidget(build(lineCount: growLineCount, streaming: true));
  await pumpFrames(tester, 20);
  expect(controller.offset, closeTo(pinnedAt, 1));

  // And the pill takes them back.
  await tester.tap(find.text('Jump to latest'));
  await pumpFrames(tester, 30);
  expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1));
  expect(find.text('Jump to latest'), findsNothing);
}

/// The gutter line-number colour must be legible (~0.75 alpha), not the
/// low-contrast hairline it used to ship at. Shared by `BeuiCodeBlock` and
/// `BeuiFileDiff`, whose gutters use the same alpha.
Future<void> expectLegibleGutterNumber(
  WidgetTester tester,
  Widget host, {
  required String lineNumberText,
}) async {
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
  final gutter = tester.widget<Text>(find.text(lineNumberText).first);
  expect(gutter.style!.color!.a, closeTo(0.75, 0.01));
}

/// The copy control's semantics label swaps to a live "Copied" once pressed,
/// so the confirmation is announced rather than silently relabelled. Shared
/// by `BeuiCodeBlock` ("Copy code") and `BeuiFileDiff` ("Copy diff").
Future<void> expectCopyConfirmationAnnounced(
  WidgetTester tester,
  Widget host, {
  required String copyLabel,
}) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
  expect(
    tester.getSemantics(find.bySemanticsLabel(copyLabel)),
    isSemantics(isLiveRegion: false),
  );

  await tester.tap(find.byIcon(LucideIcons.copy));
  await tester.pump();
  expect(
    tester.getSemantics(find.bySemanticsLabel('Copied')),
    isSemantics(isLiveRegion: true, isButton: true),
  );
  handle.dispose();
}
