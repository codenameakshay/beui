import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = SingleChildScrollView(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
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
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

const _items = [
  BeuiFileUploadItem(
    id: 'a',
    name: 'design-spec.pdf',
    size: 2411724, // ≈ 2.3 MB
    status: BeuiFileUploadStatus.uploading,
    progress: 40,
  ),
  BeuiFileUploadItem(
    id: 'b',
    name: 'logo.png',
    size: 51200, // 50 KB
    status: BeuiFileUploadStatus.success,
  ),
  BeuiFileUploadItem(
    id: 'c',
    name: 'backup.zip',
    size: 900,
    status: BeuiFileUploadStatus.error,
    error: 'Network lost',
  ),
];

void main() {
  group('BeuiFileUpload', () {
    testWidgets('renders the dropzone and fires onBrowse', (tester) async {
      var browsed = 0;
      await tester.pumpWidget(_wrap(BeuiFileUpload(onBrowse: () => browsed++)));
      await tester.pumpAndSettle();
      expect(find.text('Add files'), findsOneWidget);
      expect(find.text('Choose files to upload'), findsOneWidget);
      expect(find.text('Browse files'), findsOneWidget);
      await tester.tap(find.text('Add files'));
      expect(browsed, 1);
    });

    testWidgets('rows render name, kind · size meta and progress', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const BeuiFileUpload(value: _items)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('design-spec.pdf'), findsOneWidget);
      expect(find.text('PDF · 2.3 MB'), findsOneWidget);
      expect(find.text('PNG · 50 KB'), findsOneWidget);
      expect(find.text('ZIP · 900 B · Network lost'), findsOneWidget);
      // Status glyphs: success check + error alert.
      expect(find.byIcon(LucideIcons.circle_check), findsOneWidget);
      expect(find.byIcon(LucideIcons.circle_alert), findsOneWidget);
      // Retry appears only on the error row.
      expect(find.byIcon(LucideIcons.rotate_ccw), findsOneWidget);
    });

    testWidgets('the queue is a space-y-2 list under a space-y-3 root', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const BeuiFileUpload(value: _items)));
      await tester.pump(const Duration(milliseconds: 400));

      final a = tester.getRect(find.byKey(const ValueKey('a')));
      final b = tester.getRect(find.byKey(const ValueKey('b')));
      final c = tester.getRect(find.byKey(const ValueKey('c')));

      // Source `<ul className="space-y-2">`: rows sit 8px apart. They used to
      // be direct children of the root, which gave them its `space-y-3` 12px.
      expect(b.top - a.bottom, closeTo(8, 0.5));
      expect(c.top - b.bottom, closeTo(8, 0.5));
    });

    testWidgets('remove reports and drops the row', (tester) async {
      final removed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            defaultValue: _items,
            onRemove: (item) => removed.add(item.id),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.bySemanticsLabel('Remove logo.png'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(removed, ['b']);
      expect(find.text('logo.png'), findsNothing);
    });

    testWidgets('retry resets the failed row to uploading', (tester) async {
      final retried = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            defaultValue: _items,
            onRetry: (item) => retried.add(item.status.name),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(LucideIcons.rotate_ccw));
      await tester.pump(const Duration(milliseconds: 300));
      expect(retried, ['uploading']);
      expect(find.text('ZIP · 900 B · Network lost'), findsNothing);
      expect(find.text('ZIP · 900 B'), findsOneWidget);
    });

    testWidgets('maxFiles reached swaps the dropzone copy and blocks browse', (
      tester,
    ) async {
      var browsed = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(value: _items, maxFiles: 3, onBrowse: () => browsed++),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Upload limit reached'), findsOneWidget);
      expect(find.text('3 of 3 files added'), findsOneWidget);
      await tester.tap(find.text('Upload limit reached'), warnIfMissed: false);
      expect(browsed, 0);
    });

    testWidgets('centered variant renders', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiFileUpload(variant: BeuiFileUploadVariant.centered)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add files'), findsOneWidget);
      expect(find.byIcon(LucideIcons.cloud_upload), findsOneWidget);
    });

    testWidgets('progress bar width follows progress', (tester) async {
      Widget app(double progress) => _wrap(
        BeuiFileUpload(
          value: [
            BeuiFileUploadItem(
              id: 'p',
              name: 'video.mp4',
              size: 1024,
              status: BeuiFileUploadStatus.uploading,
              progress: progress,
            ),
          ],
        ),
      );
      await tester.pumpWidget(app(20));
      await tester.pump(const Duration(milliseconds: 400));
      double fillWidth() {
        final fill = tester.widget<FractionallySizedBox>(
          find.descendant(
            of: find.bySemanticsLabel('video.mp4 upload progress'),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        return fill.widthFactor ?? 0;
      }

      expect(fillWidth(), moreOrLessEquals(0.2, epsilon: 0.01));
      await tester.pumpWidget(app(80));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 400));
      expect(fillWidth(), moreOrLessEquals(0.8, epsilon: 0.01));
    });
  });

  group('BeuiFileUpload keyboard', () {
    testWidgets('dropzone is focusable and Enter activates onBrowse', (
      tester,
    ) async {
      var browsed = 0;
      await tester.pumpWidget(_wrap(BeuiFileUpload(onBrowse: () => browsed++)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(browsed, 1);
    });

    testWidgets('Space also activates the dropzone', (tester) async {
      var browsed = 0;
      await tester.pumpWidget(_wrap(BeuiFileUpload(onBrowse: () => browsed++)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(browsed, 1);
    });

    testWidgets('disabled dropzone does not activate on Enter', (tester) async {
      var browsed = 0;
      await tester.pumpWidget(
        _wrap(BeuiFileUpload(disabled: true, onBrowse: () => browsed++)),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(browsed, 0);
    });

    testWidgets('remove button is keyboard-activatable', (tester) async {
      final removed = <String>[];
      // No onBrowse: the dropzone is disabled and drops out of tab order,
      // so the first Tab lands directly on the row's remove control.
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            defaultValue: const [
              BeuiFileUploadItem(
                id: 'solo',
                name: 'solo.txt',
                size: 100,
                status: BeuiFileUploadStatus.success,
              ),
            ],
            onRemove: (item) => removed.add(item.id),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(removed, ['solo']);
    });
  });

  group('BeuiFileUpload semantics', () {
    testWidgets('progress semantics value ends with %', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiFileUpload(value: _items)));
      await tester.pump(const Duration(milliseconds: 400));
      final semantics = tester.widget<Semantics>(
        find.bySemanticsLabel('design-spec.pdf upload progress'),
      );
      expect(semantics.properties.value, endsWith('%'));
    });

    testWidgets('error row meta renders the error text in destructive color', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const BeuiFileUpload(value: _items)));
      await tester.pump(const Duration(milliseconds: 400));
      final richText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere(
            (t) => t.textSpan?.toPlainText().contains('Network lost') ?? false,
          );
      final span = richText.textSpan! as TextSpan;
      final errorSpan =
          span.children!.firstWhere(
                (s) => (s as TextSpan).text?.contains('Network lost') ?? false,
              )
              as TextSpan;
      expect(errorSpan.style?.color, BeuiColors.light().destructive);
      expect(errorSpan.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('dark mode uses colors.success, not a hardcoded hex', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.dark().copyWith(extensions: [BeuiColors.dark()]),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const BeuiFileUpload(value: _items),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final expectedSuccess = BeuiColors.dark().success;

      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.circle_check));
      expect(icon.color, expectedSuccess);

      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: find.bySemanticsLabel('logo.png upload progress'),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      final decoratedBox = fill.child! as DecoratedBox;
      expect((decoratedBox.decoration as BoxDecoration).color, expectedSuccess);
    });
  });

  group('BeuiFileUpload rejection and cancel', () {
    testWidgets('maxFileSize rejects an oversized item', (tester) async {
      final rejected = <BeuiFileUploadItem>[];
      const big = BeuiFileUploadItem(
        id: 'big',
        name: 'huge.mov',
        size: 60 * 1024 * 1024,
      );
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            value: const [big],
            maxFileSize: 50 * 1024 * 1024,
            onRejected: rejected.addAll,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('huge.mov'), findsNothing);
      expect(rejected.map((e) => e.id), ['big']);
      expect(
        find.textContaining('is larger than the 50 MB limit'),
        findsOneWidget,
      );
    });

    testWidgets('onCancel is used instead of onRemove while uploading', (
      tester,
    ) async {
      final cancelled = <String>[];
      final removed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            defaultValue: _items,
            onCancel: (item) => cancelled.add(item.id),
            onRemove: (item) => removed.add(item.id),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.bySemanticsLabel('Cancel upload of design-spec.pdf'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(cancelled, ['a']);
      expect(removed, isEmpty);
    });
  });
}
