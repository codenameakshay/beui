import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/agents_replay_button.dart';
import '../support.dart';

const _capture = ValueKey('round3-pixels');
const _lines = [
  BeuiFileDiffLine(id: 'context', content: 'context', oldLine: 18, newLine: 18),
  BeuiFileDiffLine(
    id: 'removed',
    type: BeuiFileDiffLineType.removed,
    content: 'removed',
    oldLine: 19,
  ),
  BeuiFileDiffLine(
    id: 'added',
    type: BeuiFileDiffLineType.added,
    content: 'added',
    newLine: 19,
  ),
];

Widget _diff({bool dark = true, bool reduce = false}) => RepaintBoundary(
  key: _capture,
  child: beuiTestApp(
    ColoredBox(
      color: dark ? const Color(0xFF151515) : const Color(0xFFFCFCFC),
      child: const BeuiFileDiff(
        file: 'src/runner.ts',
        lines: _lines,
        copyText: 'literal source payload',
        status: BeuiFileDiffStatus.complete,
        wrap: BeuiFileDiffWrap.scroll,
      ),
    ),
    width: 512,
    dark: dark,
    reduce: reduce,
    extensions: [
      BeuiColors.of(
        BeuiColorTheme.defaultMono,
        dark ? Brightness.dark : Brightness.light,
      ),
    ],
  ),
);

Future<List<int>?> _pixel(WidgetTester tester, Offset point) => tester.runAsync(
  () async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_capture))
        .toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    final pixel = List.generate(4, (i) => bytes.getUint8(offset + i));
    image.dispose();
    return pixel;
  },
);

void main() {
  testWidgets(
    'narrow diff keeps source single-line rows with horizontal access',
    (tester) async {
      const content =
          'const configuration = buildConfiguration({ retries: 3, timeout: 30000 });';
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiFileDiff(
            file: 'config.ts',
            status: BeuiFileDiffStatus.complete,
            lines: [BeuiFileDiffLine(id: 'one', content: content)],
          ),
          width: 358,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.text(content, findRichText: true)).height, 20);
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(horizontal, findsOneWidget);
      await tester.drag(horizontal, const Offset(-10000, 0));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(of: horizontal, matching: find.byType(Scrollable))
            .first,
      );
      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
      expect(scrollable.position.pixels, greaterThan(100));
    },
  );
  testWidgets('approval badge retains the source card line height', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiApprovalCard(
          status: BeuiApprovalCardStatus.approved,
          title: 'Publish the component update?',
          result: Text('Publishing was approved.'),
        ),
        width: 512,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('Approved')).style!.height, 20 / 14);
    expect(tester.getSize(find.text('Approved')).height, 16);
    expect(tester.getSize(find.byType(BeuiApprovalCard)).height, 78);
  });

  testWidgets('approval counter uses source line height and muted alpha', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiApprovalCard(
          questions: [
            BeuiApprovalCardQuestion(id: 'one', title: 'One'),
            BeuiApprovalCardQuestion(id: 'two', title: 'Two'),
          ],
        ),
        width: 512,
      ),
    );
    await tester.pumpAndSettle();
    final counter = find.text('1/2');
    expect(tester.getSize(counter).height, 16);
    final colors = BeuiColors.resolve(
      tester.element(find.byType(BeuiApprovalCard)),
    );
    expect(
      tester.widget<Text>(counter).style!.color,
      colors.mutedForeground.withValues(alpha: 0.65),
    );
  });
  testWidgets('reduced motion cancels an in-flight question exit', (
    tester,
  ) async {
    Widget card(int step, {bool reduce = false}) => beuiTestApp(
      BeuiApprovalCard(
        step: step,
        questions: const [
          BeuiApprovalCardQuestion(
            id: 'first',
            title: 'First',
            options: [BeuiApprovalCardOption(value: 'a', label: 'Outgoing')],
          ),
          BeuiApprovalCardQuestion(
            id: 'second',
            title: 'Second',
            options: [BeuiApprovalCardOption(value: 'b', label: 'Incoming')],
          ),
        ],
      ),
      width: 512,
      reduce: reduce,
    );
    await tester.pumpWidget(card(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(card(1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Outgoing'), findsOneWidget);
    expect(find.text('Incoming'), findsNothing);
    await tester.pumpWidget(card(1, reduce: true));
    expect(find.text('Outgoing'), findsNothing);
    expect(find.text('Incoming').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Incoming').hitTestable(), findsOneWidget);
  });
  testWidgets('agent replay has the source 24px box and 6px icon gap', (
    tester,
  ) async {
    var replays = 0;
    await tester.pumpWidget(
      beuiTestApp(AgentReplayButton(onPressed: () => replays++)),
    );
    final button = tester.getRect(find.byType(TextButton));
    final icon = tester.getRect(find.byIcon(LucideIcons.rotate_ccw));
    final label = tester.getRect(find.text('Replay'));
    expect(button.height, 24);
    expect(icon.left - button.left, 8);
    expect(label.left - icon.right, 6);
    expect(label.height, 16);
    await tester.tap(find.text('Replay'));
    expect(replays, 1);
  });
  testWidgets(
    'approval waits for outgoing question before entering the latest step',
    (tester) async {
      var step = 0;
      late StateSetter update;
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiApprovalCard(
                step: step,
                questions: const [
                  BeuiApprovalCardQuestion(
                    id: 'first',
                    title: 'First',
                    options: [
                      BeuiApprovalCardOption(
                        value: 'a',
                        label: 'Outgoing option',
                      ),
                    ],
                  ),
                  BeuiApprovalCardQuestion(
                    id: 'second',
                    title: 'Second',
                    options: [
                      BeuiApprovalCardOption(
                        value: 'b',
                        label: 'Skipped option',
                      ),
                    ],
                  ),
                  BeuiApprovalCardQuestion(
                    id: 'third',
                    title: 'Third',
                    options: [
                      BeuiApprovalCardOption(
                        value: 'c',
                        label: 'Latest option',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          width: 512,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Outgoing option'), findsOneWidget);
      update(() => step = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Outgoing option'), findsOneWidget);
      expect(find.text('Skipped option'), findsNothing);
      update(() => step = 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 121));
      await tester.pump();
      expect(find.text('Outgoing option'), findsNothing);
      expect(find.text('Skipped option'), findsNothing);
      expect(find.text('Latest option'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Latest option').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('approval description radio aligns with the first text line', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiApprovalCard(
          questions: [
            BeuiApprovalCardQuestion(
              id: 'scope',
              title: 'Scope',
              options: [
                BeuiApprovalCardOption(
                  value: 'focused',
                  label: 'Starter',
                  description: 'Polished pieces',
                ),
              ],
            ),
          ],
        ),
        width: 512,
      ),
    );
    await tester.pumpAndSettle();
    final ring = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is AnimatedContainer && w.constraints?.maxWidth == 20,
      ),
    );
    expect(ring.top, tester.getRect(find.text('Starter')).top);
    await tester.tap(find.text('Polished pieces'));
    await tester.pumpAndSettle();
    expect(find.byType(BeuiRadioGroup<String>), findsOneWidget);
    final group = tester.widget<BeuiRadioGroup<String>>(
      find.byType(BeuiRadioGroup<String>),
    );
    expect(group.value, 'focused');
  });
  for (final reduce in [false, true]) {
    testWidgets(
      'copy belongs to the disclosure and survives reopen, reduce=$reduce',
      (tester) async {
        final copied = <String?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String?);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(_diff(reduce: reduce));
        await tester.pumpAndSettle();
        final header = tester.getRect(find.text('src/runner.ts'));
        final copy = find.byIcon(LucideIcons.copy);
        final copyRect = tester.getRect(copy);
        final row = tester.getRect(find.textContaining('added'));
        expect(copyRect.top, greaterThanOrEqualTo(row.bottom + 4));
        expect(copyRect.right, lessThan(header.left + 512));
        await tester.tap(copy);
        await tester.pump();
        expect(copied, ['literal source payload']);
        expect(find.bySemanticsLabel('Copied'), findsOneWidget);
        await tester.tap(find.text('src/runner.ts'));
        await tester.pumpAndSettle();
        expect(find.textContaining('added'), findsNothing);
        expect(find.byIcon(LucideIcons.copy), findsNothing);
        await tester.tap(find.text('src/runner.ts'));
        await tester.pumpAndSettle();
        expect(find.textContaining('added'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1600));
        expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets('source diff row washes and gutter offsets, dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(_diff(dark: dark));
      await tester.pumpAndSettle();
      final box = tester.getRect(find.byType(BeuiFileDiff));
      final headerIcon = tester.getRect(find.byIcon(LucideIcons.file_code));
      expect(headerIcon.left, box.left);
      final context = tester.getRect(find.textContaining('context'));
      expect(context.left - box.left, 24 + 36 + 36 + 16 + 6);
      expect(context.top - box.top, 42);
      final removed = tester.getRect(find.textContaining('removed'));
      final added = tester.getRect(find.textContaining('added'));
      final x = box.right - 20;
      expect(
        await _pixel(tester, Offset(x, context.top + 5)),
        dark ? [27, 27, 27, 255] : [246, 246, 246, 255],
      );
      expect(
        await _pixel(tester, Offset(x, removed.top + 5)),
        dark ? [43, 27, 31, 255] : [247, 231, 235, 255],
      );
      expect(
        await _pixel(tester, Offset(x, added.top + 5)),
        dark ? [25, 38, 34, 255] : [229, 242, 238, 255],
      );
    });
  }
}
