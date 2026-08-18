import 'dart:typed_data';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1×1 transparent PNG — enough to give an image row a real [ImageProvider]
/// without reaching for an asset or the network.
final _pixel = MemoryImage(
  Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, //
    1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, //
    65, 84, 120, 156, 99, 96, 0, 2, 0, 0, 5, 0, 1, 122, 94, 171, 63, 0, 0, //
    0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]),
);

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
  BeuiAttachmentUploadItem(
    id: 'brief',
    name: 'launch-brief.pdf',
    size: 2411724, // ≈ 2.3 MB
    status: BeuiAttachmentStatus.failed,
    error: 'Upload failed',
  ),
  BeuiAttachmentUploadItem(
    id: 'docs',
    name: 'beui.dev',
    kind: BeuiAttachmentKind.link,
    href: 'https://beui.dev',
  ),
  BeuiAttachmentUploadItem(
    id: 'voice-note',
    name: 'launch-note.m4a',
    kind: BeuiAttachmentKind.audio,
    currentTime: Duration(seconds: 12),
    duration: Duration(seconds: 48),
  ),
];

BeuiAttachmentUploadItem _candidate(String id, {int size = 1024}) =>
    BeuiAttachmentUploadItem(id: id, name: '$id.pdf', size: size);

/// Long enough to drain the add pipeline's timers (900ms upload + 1000ms hold)
/// plus the arrival stagger.
const _settleAdd = Duration(milliseconds: 2400);

void main() {
  group('BeuiAttachmentUpload — dropzone', () {
    testWidgets('renders the default copy and fires onBrowse', (tester) async {
      var browsed = 0;
      await tester.pumpWidget(
        _wrap(BeuiAttachmentUpload(onBrowse: () => browsed++)),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Drag and drop or browse files'), findsOneWidget);
      expect(find.text('Maximum 500 MB file size'), findsOneWidget);
      expect(find.byIcon(LucideIcons.upload), findsOneWidget);

      await tester.tap(find.text('Drag and drop or browse files'));
      expect(browsed, 1);
    });

    testWidgets('maxFileSize drives the byline', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiAttachmentUpload(maxFileSize: 5 * 1024 * 1024)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Maximum 5 MB file size'), findsOneWidget);
    });

    testWidgets('max-files swaps the copy and blocks browse', (tester) async {
      var browsed = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            value: _items,
            maxFiles: 3,
            onBrowse: () => browsed++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Attachment limit reached'), findsOneWidget);
      expect(find.text('3 of 3 attachments added'), findsOneWidget);
      await tester.tap(
        find.text('Attachment limit reached'),
        warnIfMissed: false,
      );
      expect(browsed, 0);
    });
  });

  group('BeuiAttachmentUpload — rows', () {
    testWidgets('file, link and audio rows render their own slots', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            value: _items,
            attachmentsLabel: 'Attachments:',
            onRetry: (_) {},
            onOpenLink: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Attachments:'), findsOneWidget);

      // File row: name + size + the failure note.
      expect(find.text('launch-brief.pdf'), findsOneWidget);
      expect(find.text('2.3 MB'), findsOneWidget);
      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.byIcon(LucideIcons.rotate_ccw), findsOneWidget);

      // Link row: "Web" instead of a size, plus the open affordance.
      expect(find.text('beui.dev'), findsOneWidget);
      expect(find.text('Web'), findsOneWidget);
      expect(find.bySemanticsLabel('Open beui.dev'), findsOneWidget);

      // Audio row: elapsed / total, no name, and a play button.
      expect(find.text('0:12'), findsOneWidget);
      expect(find.text('0:48'), findsOneWidget);
      expect(find.text('launch-note.m4a'), findsNothing);
      // The mark is painted, not an icon-font glyph (the source fills it), so
      // the toggle's state reads off its semantics label as the source's does.
      expect(find.bySemanticsLabel('Play launch-note.m4a'), findsOneWidget);
    });

    testWidgets('a failed row without onRetry is a static alert', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const BeuiAttachmentUpload(value: _items)));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(LucideIcons.rotate_ccw), findsNothing);
      expect(find.byIcon(LucideIcons.circle_alert), findsOneWidget);
      expect(
        find.bySemanticsLabel('Upload failed for launch-brief.pdf'),
        findsOneWidget,
      );
    });

    testWidgets('retry reports the row and leaves the list alone', (
      tester,
    ) async {
      final retried = <String>[];
      final changes = <int>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            defaultValue: _items,
            onRetry: (item) => retried.add(item.id),
            onValueChange: (next) => changes.add(next.length),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.bySemanticsLabel('Retry launch-brief.pdf'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(retried, ['brief']);
      // Source parity: retry only notifies; the consumer owns the status flip.
      expect(changes, isEmpty);
      expect(find.text('launch-brief.pdf'), findsOneWidget);
    });
  });

  group('BeuiAttachmentUpload — removal', () {
    testWidgets('removal spins first, then drops the row', (tester) async {
      final removed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            defaultValue: _items,
            onRemove: (item) => removed.add(item.id),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.bySemanticsLabel('Remove beui.dev'));
      await tester.pump();

      // Pending window: the spinner replaces the remove button, and the row is
      // still in the list (source REMOVE_PENDING_MS = 420ms).
      expect(find.bySemanticsLabel('Removing beui.dev'), findsOneWidget);
      expect(removed, isEmpty);
      expect(find.text('beui.dev'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(removed, ['docs']);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('beui.dev'), findsNothing);
    });

    testWidgets('a second remove press during the pending window is ignored', (
      tester,
    ) async {
      final removed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            defaultValue: _items,
            onRemove: (item) => removed.add(item.id),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.bySemanticsLabel('Remove beui.dev'));
      await tester.pump(const Duration(milliseconds: 100));
      // The button is now a spinner, so there is nothing left to press —
      // asserting that is the guard against a double finalize.
      expect(find.bySemanticsLabel('Remove beui.dev'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(removed, ['docs']);
    });
  });

  group('BeuiAttachmentUpload — add pipeline', () {
    testWidgets('controller.add appends and announces', (tester) async {
      final controller = BeuiAttachmentUploadController();
      final added = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            controller: controller,
            onAttachmentsAdded: (items) =>
                added.addAll(items.map((item) => item.id)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.isAttached, isTrue);

      controller.add([_candidate('a'), _candidate('b')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(added, ['a', 'b']);
      expect(find.text('a.pdf'), findsOneWidget);
      expect(find.text('b.pdf'), findsOneWidget);
      await tester.pump(_settleAdd);
    });

    testWidgets('oversized candidates are rejected as too-large', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      final rejected = <(String, BeuiAttachmentRejectReason)>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            controller: controller,
            maxFileSize: 2048,
            onAttachmentsRejected: (items, reason) {
              for (final item in items) {
                rejected.add((item.id, reason));
              }
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      controller.add([
        _candidate('small', size: 1024),
        _candidate('huge', size: 999999),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(rejected, [('huge', BeuiAttachmentRejectReason.tooLarge)]);
      expect(find.text('small.pdf'), findsOneWidget);
      expect(find.text('huge.pdf'), findsNothing);
      await tester.pump(_settleAdd);
    });

    testWidgets('a full workspace rejects everything as max-files', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      final rejected = <(String, BeuiAttachmentRejectReason)>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            controller: controller,
            defaultValue: _items,
            maxFiles: 3,
            onAttachmentsRejected: (items, reason) {
              for (final item in items) {
                rejected.add((item.id, reason));
              }
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      controller.add([_candidate('x')]);
      await tester.pump(const Duration(milliseconds: 400));

      expect(rejected, [('x', BeuiAttachmentRejectReason.maxFiles)]);
      expect(find.text('x.pdf'), findsNothing);
    });

    testWidgets('a partial overflow accepts the slots and rejects the rest', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      final rejected = <(String, BeuiAttachmentRejectReason)>[];
      final added = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            controller: controller,
            maxFiles: 2,
            onAttachmentsAdded: (items) =>
                added.addAll(items.map((item) => item.id)),
            onAttachmentsRejected: (items, reason) {
              for (final item in items) {
                rejected.add((item.id, reason));
              }
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      controller.add([_candidate('a'), _candidate('b'), _candidate('c')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(added, ['a', 'b']);
      expect(rejected, [('c', BeuiAttachmentRejectReason.maxFiles)]);
      await tester.pump(_settleAdd);
    });

    testWidgets('added rows run uploading → complete → idle', (tester) async {
      final controller = BeuiAttachmentUploadController();
      await tester.pumpWidget(
        _wrap(BeuiAttachmentUpload(controller: controller)),
      );
      await tester.pump(const Duration(milliseconds: 400));

      controller.add([_candidate('a')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Uploading: the action slot is blank (no remove, no check).
      expect(find.bySemanticsLabel('Remove a.pdf'), findsNothing);
      expect(find.byIcon(LucideIcons.check), findsNothing);

      // UPLOAD_PROGRESS_MS = 900ms → complete.
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(
        find.bySemanticsLabel('Upload complete for a.pdf'),
        findsOneWidget,
      );

      // UPLOAD_COMPLETE_HOLD_MS = 1000ms → back to the remove affordance.
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(LucideIcons.check), findsNothing);
      expect(find.bySemanticsLabel('Remove a.pdf'), findsOneWidget);
    });

    testWidgets('add is a no-op while disabled', (tester) async {
      final controller = BeuiAttachmentUploadController();
      final added = <String>[];
      final rejected = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            controller: controller,
            disabled: true,
            onAttachmentsAdded: (items) =>
                added.addAll(items.map((item) => item.id)),
            onAttachmentsRejected: (items, _) =>
                rejected.addAll(items.map((item) => item.id)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      controller.add([_candidate('a')]);
      await tester.pump(const Duration(milliseconds: 400));

      expect(added, isEmpty);
      expect(rejected, isEmpty);
      expect(find.text('a.pdf'), findsNothing);
    });
  });

  group('BeuiAttachmentUpload — images', () {
    testWidgets('an image row without a preview falls back to a glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiAttachmentUpload(
            value: [
              BeuiAttachmentUploadItem(
                id: 'shot',
                name: 'shot.png',
                kind: BeuiAttachmentKind.image,
                size: 51200,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(LucideIcons.file_image), findsOneWidget);
      expect(find.bySemanticsLabel('Preview shot.png'), findsNothing);
    });

    testWidgets('a previewable image row opens and closes the overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            value: [
              BeuiAttachmentUploadItem(
                id: 'shot',
                name: 'shot.png',
                kind: BeuiAttachmentKind.image,
                size: 51200,
                preview: _pixel,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.bySemanticsLabel('Preview shot.png'), findsOneWidget);
      expect(find.bySemanticsLabel('Close image preview'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Preview shot.png'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Close image preview'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close image preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Close image preview'), findsNothing);
    });
  });

  group('BeuiAttachmentUpload — audio', () {
    testWidgets('the toggle reports and the glyph follows playingId', (
      tester,
    ) async {
      final toggled = <String>[];
      Widget app(String? playingId) => _wrap(
        BeuiAttachmentUpload(
          value: _items,
          playingId: playingId,
          onAudioToggle: (item) => toggled.add(item.id),
        ),
      );

      await tester.pumpWidget(app(null));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Play launch-note.m4a'), findsOneWidget);
      expect(find.bySemanticsLabel('Pause launch-note.m4a'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Play launch-note.m4a'));
      await tester.pump();
      expect(toggled, ['voice-note']);

      await tester.pumpWidget(app('voice-note'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Pause launch-note.m4a'), findsOneWidget);
      expect(find.bySemanticsLabel('Play launch-note.m4a'), findsNothing);

      // Stop the waveform's repeating pulse before the test ends.
      await tester.pumpWidget(app(null));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('BeuiAttachmentUpload — controlled vs uncontrolled', () {
    testWidgets('uncontrolled owns its own list', (tester) async {
      final changes = <List<String>>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            defaultValue: _items,
            onValueChange: (next) =>
                changes.add(next.map((item) => item.id).toList()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.bySemanticsLabel('Remove beui.dev'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));

      expect(changes, [
        ['brief', 'voice-note'],
      ]);
      expect(find.text('beui.dev'), findsNothing);
    });

    testWidgets('controlled defers to the parent', (tester) async {
      final changes = <List<String>>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            value: _items,
            onValueChange: (next) =>
                changes.add(next.map((item) => item.id).toList()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.bySemanticsLabel('Remove beui.dev'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));

      // The widget asks, but `value` never changed — so the row stays.
      expect(changes, [
        ['brief', 'voice-note'],
      ]);
      expect(find.text('beui.dev'), findsOneWidget);
    });
  });

  group('BeuiAttachmentUpload — reduced motion', () {
    testWidgets('rows settle with no transform delta', (tester) async {
      Future<Offset> travel({required bool reduce}) async {
        await tester.pumpWidget(
          _wrap(const BeuiAttachmentUpload(value: _items), reduce: reduce),
        );
        await tester.pump();
        final first = tester.getTopLeft(find.text('launch-brief.pdf'));
        await tester.pump(const Duration(milliseconds: 400));
        final settled = tester.getTopLeft(find.text('launch-brief.pdf'));
        return settled - first;
      }

      // Movement-bearing entrance without reduced motion…
      expect(await travel(reduce: false), isNot(Offset.zero));
      // …and no movement at all with it (opacity may still settle).
      expect(await travel(reduce: true), Offset.zero);
    });

    testWidgets('reduced motion shortens the removal window', (tester) async {
      final removed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            defaultValue: _items,
            onRemove: (item) => removed.add(item.id),
          ),
          reduce: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.bySemanticsLabel('Remove beui.dev'));
      await tester.pump();
      expect(removed, isEmpty);
      // 140ms under reduced motion instead of REMOVE_PENDING_MS (420ms).
      await tester.pump(const Duration(milliseconds: 200));
      expect(removed, ['docs']);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('progress, cancel and seeking', () {
    testWidgets('a real progress value drives the wash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiAttachmentUpload(
            defaultValue: [
              BeuiAttachmentUploadItem(
                id: 'big',
                name: 'render.mov',
                size: 200000000,
                status: BeuiAttachmentStatus.uploading,
                progress: 0.42,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // The percentage is spoken, so the row is not just a moving colour.
      expect(
        find.bySemanticsLabel('Uploading render.mov, 42%'),
        findsOneWidget,
      );
    });

    testWidgets('an in-flight upload can be cancelled, not just removed', (
      tester,
    ) async {
      final cancelled = <String>[];
      final removed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            defaultValue: const [
              BeuiAttachmentUploadItem(
                id: 'big',
                name: 'render.mov',
                size: 200000000,
                status: BeuiAttachmentStatus.uploading,
              ),
            ],
            onCancel: (item) => cancelled.add(item.id),
            onRemove: (item) => removed.add(item.id),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // The slot used to be blank for the whole transfer.
      expect(
        find.bySemanticsLabel('Cancel upload of render.mov'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Cancel upload of render.mov'));
      await tester.pump();
      // Cancelling is its own act — it must not read as a delete.
      expect(cancelled, ['big']);
      expect(removed, isEmpty);
    });

    testWidgets('without onCancel the uploading slot stays blank', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiAttachmentUpload(
            defaultValue: [
              BeuiAttachmentUploadItem(
                id: 'big',
                name: 'render.mov',
                status: BeuiAttachmentStatus.uploading,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.bySemanticsLabel('Cancel upload of render.mov'),
        findsNothing,
      );
    });

    testWidgets('the waveform is inert until onSeek is wired', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiAttachmentUpload(defaultValue: _items)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      // Documented as a scrubber, but read-only without a handler.
      expect(find.bySemanticsLabel('Seek launch-note.m4a'), findsNothing);
    });

    testWidgets('a wired waveform scrubs on tap and on arrow keys', (
      tester,
    ) async {
      final seeks = <Duration>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAttachmentUpload(
            defaultValue: _items,
            onSeek: (item, position) => seeks.add(position),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final scrubber = find.bySemanticsLabel('Seek launch-note.m4a');
      expect(scrubber, findsOneWidget);

      // Tap dead centre of a 48s clip → about half way.
      await tester.tap(scrubber);
      await tester.pump();
      expect(seeks, hasLength(1));
      expect(seeks.single.inSeconds, closeTo(24, 2));

      // Drag scrubs continuously rather than only on release.
      seeks.clear();
      await tester.drag(scrubber, const Offset(30, 0));
      await tester.pump();
      expect(seeks, isNotEmpty);
    });

    testWidgets('the scrubber reports itself as a slider with a position', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(BeuiAttachmentUpload(defaultValue: _items, onSeek: (_, _) {})),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final node = tester.getSemantics(
        find.bySemanticsLabel('Seek launch-note.m4a'),
      );
      expect(node.label, 'Seek launch-note.m4a');
      // 12s of 48s, spoken as a real timestamp rather than a raw fraction.
      expect(node.value, '0:12');
      // Arrow keys / screen-reader swipes step the playhead.
      expect(node.increasedValue, isNotEmpty);
      expect(node.decreasedValue, isNotEmpty);
      handle.dispose();
    });
  });
}
