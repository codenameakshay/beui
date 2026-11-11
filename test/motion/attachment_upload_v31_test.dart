import 'dart:async';

import 'package:beui/src/motion/attachment_upload.dart';
import 'package:beui/src/motion/upload_file.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';
import 'package:beui/src/tokens/icons.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileSelector extends FileSelectorPlatform {
  Completer<List<XFile>>? filesResult;
  Completer<XFile?>? fileResult;
  int openFilesCalls = 0;
  int openFileCalls = 0;

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) {
    openFilesCalls++;
    return (filesResult ??= Completer<List<XFile>>()).future;
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) {
    openFileCalls++;
    return (fileResult ??= Completer<XFile?>()).future;
  }
}

class _TrackedXFile extends XFile {
  _TrackedXFile(this.bytes, {required this.fileName, required this.contentType})
    : super.fromData(bytes, name: fileName, mimeType: contentType);

  final Uint8List bytes;
  final String fileName;
  final String contentType;
  int byteReads = 0;
  int streamOpens = 0;

  @override
  String get name => fileName;

  @override
  String get mimeType => contentType;

  @override
  Future<int> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async {
    byteReads++;
    return bytes;
  }

  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    streamOpens++;
    return Stream<Uint8List>.value(bytes);
  }
}

late FileSelectorPlatform _originalSelector;
late _FileSelector _selector;
const _previewLimit = 8 * 1024 * 1024;

final _pixelBytes = Uint8List.fromList(const [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  96,
  0,
  2,
  0,
  0,
  5,
  0,
  1,
  122,
  94,
  171,
  63,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _originalSelector = FileSelectorPlatform.instance;
  setUp(() {
    _selector = _FileSelector();
    FileSelectorPlatform.instance = _selector;
  });
  tearDown(() => FileSelectorPlatform.instance = _originalSelector);

  group('AttachmentUpload v3.1 file acquisition', () {
    testWidgets('selection preserves metadata, lazy bytes, status and order', (
      tester,
    ) async {
      final order = <String>[];
      List<BeuiAttachmentUploadItem>? acceptedItems;
      List<BeuiUploadFile>? acceptedFiles;
      final controller = BeuiAttachmentUploadController();
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            controller: controller,
            accept: 'image/png',
            multiple: true,
            onValueChange: (_) => order.add('value'),
            onAttachmentsAdded: (_) => order.add('legacy-added'),
            onFilesAdded: (items, files) {
              order.add('files-added');
              acceptedItems = items;
              acceptedFiles = files;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Drag and drop or browse files'));
      expect(_selector.openFilesCalls, 1);
      expect(_selector.openFileCalls, 0);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final first = _TrackedXFile(
        bytes,
        fileName: 'first.txt',
        contentType: 'text/plain',
      );
      _selector.filesResult!.complete([
        first,
        _TrackedXFile(bytes, fileName: 'second.txt', contentType: 'text/plain'),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(order, ['value', 'legacy-added', 'files-added']);
      expect(find.bySemanticsLabel('Uploading first.txt'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove first.txt'), findsNothing);
      expect(acceptedItems!.map((item) => item.name), [
        'first.txt',
        'second.txt',
      ]);
      expect(acceptedItems!.map((item) => item.status), [
        BeuiAttachmentStatus.idle,
        BeuiAttachmentStatus.idle,
      ]);
      expect(
        acceptedItems!.every((item) => item.kind == BeuiAttachmentKind.file),
        isTrue,
      );
      expect(acceptedFiles!.map((file) => file.name), [
        'first.txt',
        'second.txt',
      ]);
      expect(acceptedFiles!.map((file) => file.size), [3, 3]);
      expect(first.byteReads, 0);
      expect(first.streamOpens, 0);
      expect(await acceptedFiles!.first.readAsBytes(), bytes);
      expect(first.byteReads, 1);
      expect(await acceptedFiles!.first.openRead().toList(), [bytes]);
      expect(first.streamOpens, 1);
      await tester.pump(const Duration(milliseconds: 2400));
    });

    testWidgets('legacy and raw rejection callbacks retain source precedence', (
      tester,
    ) async {
      final events = <String>[];
      final controller = BeuiAttachmentUploadController();
      final smallFile = _capability('small.txt', 1);
      final largeFile = _capability('large.txt', 9);
      final tailFile = _capability('tail.txt', 1);
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            controller: controller,
            maxFiles: 2,
            maxFileSize: 5,
            onAttachmentsRejected: (items, reason) => events.add(
              'legacy-rejected:${reason.name}:${items.map((item) => item.name).join(',')}',
            ),
            onFilesRejected: (files, reason) => events.add(
              'files-rejected:${reason.name}:${files.map((file) => file.name).join(',')}',
            ),
            onValueChange: (_) => events.add('value'),
            onAttachmentsAdded: (_) => events.add('legacy-added'),
            onFilesAdded: (_, files) => events.add(
              'files-added:${files.map((file) => file.name).join(',')}',
            ),
          ),
        ),
      );
      await tester.pump();

      controller.add([
        _candidate('small', file: smallFile),
        _candidate('large', size: 9, file: largeFile),
        _candidate('tail', file: tailFile),
      ]);
      await tester.pump();

      expect(events, [
        'legacy-rejected:tooLarge:large.txt',
        'files-rejected:tooLarge:large.txt',
        'legacy-rejected:maxFiles:tail.txt',
        'files-rejected:maxFiles:tail.txt',
        'value',
        'legacy-added',
        'files-added:small.txt',
      ]);
      await tester.pump(const Duration(milliseconds: 2400));
    });

    testWidgets('controlled current value is used for each later gate', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      final changes = <List<String>>[];
      var value = <BeuiAttachmentUploadItem>[_candidate('seed')];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => BeuiAttachmentUpload(
              value: value,
              controller: controller,
              maxFiles: 2,
              onValueChange: (next) {
                changes.add(next.map((item) => item.id).toList());
                setState(() => value = next);
              },
              onAttachmentsRejected: (items, reason) {
                changes.add(['${reason.name}:${items.single.name}']);
              },
            ),
          ),
        ),
      );
      await tester.pump();

      controller.add([_candidate('first')]);
      await tester.pump();
      controller.add([_candidate('overflow')]);
      await tester.pump();

      expect(changes, [
        ['seed', 'first'],
        ['maxFiles:overflow.txt'],
      ]);
      await tester.pump(const Duration(milliseconds: 2400));
    });

    testWidgets('onBrowse overrides the built-in picker exclusively', (
      tester,
    ) async {
      var browsed = 0;
      await tester.pumpWidget(
        _app(BeuiAttachmentUpload(onBrowse: () => browsed++)),
      );
      await tester.pump();

      await tester.tap(find.text('Drag and drop or browse files'));
      expect(browsed, 1);
      expect(_selector.openFilesCalls, 0);
      expect(_selector.openFileCalls, 0);
    });

    testWidgets('picker cancellation and disposal suppress late callbacks', (
      tester,
    ) async {
      final events = <String>[];
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            onValueChange: (_) => events.add('value'),
            onFilesAdded: (_, _) => events.add('added'),
            onFilesRejected: (_, _) => events.add('rejected'),
            onAcquisitionError: (_, _) => events.add('error'),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Drag and drop or browse files'));
      expect(_selector.openFilesCalls, 1);
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      _selector.filesResult!.complete([
        XFile.fromData(Uint8List.fromList([1]), name: 'late.txt'),
      ]);
      await tester.pump();
      expect(events, isEmpty);
    });

    testWidgets('a custom browse override supersedes a pending picker', (
      tester,
    ) async {
      final added = <String>[];
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            onFilesAdded: (_, files) =>
                added.addAll(files.map((file) => file.name)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Drag and drop or browse files'));
      expect(_selector.openFilesCalls, 1);

      await tester.pumpWidget(_app(BeuiAttachmentUpload(onBrowse: () {})));
      _selector.filesResult!.complete([
        XFile.fromData(Uint8List.fromList([1]), name: 'stale.txt'),
      ]);
      await tester.pump();
      expect(added, isEmpty);
    });

    testWidgets('a new picker supersedes the old result', (tester) async {
      final added = <String>[];
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            onFilesAdded: (_, files) =>
                added.addAll(files.map((file) => file.name)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Drag and drop or browse files'));
      final oldResult = _selector.filesResult!;
      _selector.filesResult = Completer<List<XFile>>();
      await tester.tap(find.text('Drag and drop or browse files'));
      expect(_selector.openFilesCalls, 2);
      oldResult.complete([
        _TrackedXFile(
          Uint8List.fromList([1]),
          fileName: 'old.txt',
          contentType: 'text/plain',
        ),
      ]);
      await tester.pump();
      expect(added, isEmpty);
      _selector.filesResult!.complete([
        _TrackedXFile(
          Uint8List.fromList([2]),
          fileName: 'new.txt',
          contentType: 'text/plain',
        ),
      ]);
      await tester.pump();
      expect(added, ['new.txt']);
      await tester.pump(const Duration(milliseconds: 2400));
    });

    testWidgets('raw callbacks pair only file-backed controller items', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      final legacy = <String>[];
      final rawItems = <String>[];
      final rawFiles = <String>[];
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            controller: controller,
            onAttachmentsAdded: (items) =>
                legacy.addAll(items.map((item) => item.id)),
            onFilesAdded: (items, files) {
              rawItems.addAll(items.map((item) => item.id));
              rawFiles.addAll(files.map((file) => file.name));
            },
          ),
        ),
      );
      await tester.pump();
      controller.add([
        _candidate('metadata'),
        _candidate('file', file: _capability('file.txt', 1)),
      ]);
      await tester.pump();
      expect(legacy, ['metadata', 'file']);
      expect(rawItems, ['file']);
      expect(rawFiles, ['file.txt']);
      await tester.pump(const Duration(milliseconds: 2400));
    });

    testWidgets('single-file picker cancel is silent', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            multiple: false,
            accept: '.pdf',
            onValueChange: (_) => events.add('value'),
            onFilesAdded: (_, _) => events.add('added'),
            onFilesRejected: (_, _) => events.add('rejected'),
            onAcquisitionError: (_, _) => events.add('error'),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Drag and drop or browse files'));
      expect(_selector.openFileCalls, 1);
      expect(_selector.openFilesCalls, 0);
      _selector.fileResult!.complete(null);
      await tester.pump();
      expect(events, isEmpty);
    });

    testWidgets('keyboard activation picks and disabled state blocks it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const BeuiAttachmentUpload()));
      await tester.pump();
      final zone = find.text('Drag and drop or browse files');
      Focus.of(tester.element(zone)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(_selector.openFilesCalls, 1);
      _selector.filesResult!.complete(const []);
      await tester.pump();

      await tester.pumpWidget(_app(const BeuiAttachmentUpload(disabled: true)));
      await tester.pump();
      Focus.of(tester.element(zone)).requestFocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(_selector.openFilesCalls, 1);
    });

    testWidgets('picker failures use the acquisition error callback once', (
      tester,
    ) async {
      final errors = <Object>[];
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            onAcquisitionError: (error, _) => errors.add(error),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Drag and drop or browse files'));
      _selector.filesResult!.completeError(StateError('picker failed'));
      await tester.pump();
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });

    testWidgets(
      'late file preview reads are ignored after disposal',
      (tester) async {
        final controller = BeuiAttachmentUploadController();
        var streamOpens = 0;
        var streamCancels = 0;
        final bytes = StreamController<List<int>>(
          onCancel: () {
            streamCancels++;
          },
        );
        final bytesDone = bytes.done;
        final errors = <Object>[];
        final file = BeuiUploadFile(
          name: 'flower.png',
          size: 3,
          mimeType: 'image/png',
          readAsBytes: () async => throw StateError('unexpected byte read'),
          openRead: () {
            streamOpens++;
            return bytes.stream;
          },
        );
        await tester.pumpWidget(
          _app(
            BeuiAttachmentUpload(
              controller: controller,
              onAcquisitionError: (error, _) => errors.add(error),
            ),
          ),
        );
        await tester.pump();

        controller.add([
          BeuiAttachmentUploadItem(
            id: 'flower',
            name: 'flower.png',
            kind: BeuiAttachmentKind.image,
            size: 3,
            file: file,
          ),
        ]);
        await tester.pump();
        expect(streamOpens, 1);

        await tester.pumpWidget(_app(const SizedBox.shrink()));
        expect(streamCancels, 1);
        await bytes.close();
        await bytesDone;
        await tester.pump();

        expect(errors, isEmpty);
        expect(tester.takeException(), isNull);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets('file previews read only when displayed and bound decoding', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      var streamOpens = 0;
      final file = BeuiUploadFile(
        name: 'flower.png',
        size: _pixelBytes.length,
        mimeType: 'image/png',
        readAsBytes: () async => throw StateError('unexpected byte read'),
        openRead: () {
          streamOpens++;
          return Stream<List<int>>.value(_pixelBytes);
        },
      );
      await tester.pumpWidget(
        _app(BeuiAttachmentUpload(controller: controller)),
      );
      await tester.pump();
      expect(streamOpens, 0);

      controller.add([
        BeuiAttachmentUploadItem(
          id: 'flower',
          name: 'flower.png',
          kind: BeuiAttachmentKind.image,
          size: _pixelBytes.length,
          file: file,
        ),
      ]);
      await tester.pump();
      expect(streamOpens, 1);
      await _flushExternalStreamCleanup(tester);

      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.image, isA<ResizeImage>());
      await tester.pump(const Duration(milliseconds: 2400));
    });

    testWidgets('declared over-budget image stays accepted without reading', (
      tester,
    ) async {
      final payload = Uint8List(_previewLimit + 1);
      final source = _TrackedXFile(
        payload,
        fileName: 'large.png',
        contentType: 'image/png',
      );
      List<BeuiAttachmentUploadItem>? accepted;
      List<BeuiUploadFile>? rawFiles;
      late VoidCallback rebuild;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = () => setState(() {});
              return BeuiAttachmentUpload(
                onFilesAdded: (items, files) {
                  accepted = items;
                  rawFiles = files;
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Drag and drop or browse files'));
      _selector.filesResult!.complete([source]);
      await tester.pump();

      expect(accepted!.single.kind, BeuiAttachmentKind.image);
      expect(accepted!.single.status, BeuiAttachmentStatus.idle);
      expect(rawFiles!.single.name, 'large.png');
      expect(source.streamOpens, 0);
      expect(source.byteReads, 0);
      expect(await rawFiles!.single.readAsBytes(), payload);
      expect(await rawFiles!.single.readAsBytes(), payload);
      expect(source.byteReads, 2);
      rebuild();
      await tester.pump();
      expect(source.streamOpens, 0);
    });

    testWidgets('consumer preview bypasses the automatic file reader', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      var streamOpens = 0;
      var byteReads = 0;
      await tester.pumpWidget(
        _app(BeuiAttachmentUpload(controller: controller)),
      );
      await tester.pump();
      controller.add([
        BeuiAttachmentUploadItem(
          id: 'provided-preview',
          name: 'provided.png',
          kind: BeuiAttachmentKind.image,
          size: 4,
          preview: MemoryImage(_pixelBytes),
          file: BeuiUploadFile(
            name: 'provided.png',
            size: 4,
            readAsBytes: () async {
              byteReads++;
              return _pixelBytes;
            },
            openRead: () {
              streamOpens++;
              return Stream<List<int>>.value(_pixelBytes);
            },
          ),
        ),
      ]);
      await tester.pump();

      expect(streamOpens, 0);
      expect(byteReads, 0);
    });

    testWidgets('complete below-limit and exact-limit streams can decode', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      final exactStream = StreamController<List<int>>();
      final exactDone = exactStream.done;
      var exactOpens = 0;
      var belowOpens = 0;
      final exact = Uint8List(_previewLimit)
        ..setRange(0, _pixelBytes.length, _pixelBytes);
      final below = Uint8List(_previewLimit - 1)
        ..setRange(0, _pixelBytes.length, _pixelBytes);
      final files = [
        BeuiUploadFile(
          name: 'exact.png',
          size: 1,
          readAsBytes: () async => throw StateError('unexpected byte read'),
          openRead: () {
            exactOpens++;
            return exactStream.stream;
          },
        ),
        BeuiUploadFile(
          name: 'below.png',
          size: 1,
          readAsBytes: () async => throw StateError('unexpected byte read'),
          openRead: () {
            belowOpens++;
            return Stream<List<int>>.value(below);
          },
        ),
      ];
      await tester.pumpWidget(
        _app(BeuiAttachmentUpload(controller: controller)),
      );
      await tester.pump();
      controller.add([
        for (var i = 0; i < files.length; i++)
          BeuiAttachmentUploadItem(
            id: 'complete-$i',
            name: 'complete-$i.png',
            kind: BeuiAttachmentKind.image,
            size: files[i].size,
            file: files[i],
          ),
      ]);
      await tester.pump();

      expect(exactOpens, 1);
      expect(belowOpens, 0);
      exactStream.add(exact);
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(belowOpens, 0);

      await exactStream.close();
      await exactDone;
      await _flushExternalStreamCleanup(tester);
      await _flushExternalStreamCleanup(tester);
      expect(exactOpens, 1);
      expect(belowOpens, 1);
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('understated-size overflow cancels without decoding prefix', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      var cancellations = 0;
      var byteReads = 0;
      var streamOpens = 0;
      var errors = 0;
      late VoidCallback rebuild;
      final stream = StreamController<List<int>>(
        sync: true,
        onCancel: () => cancellations++,
      );
      final streamDone = stream.done;
      final file = BeuiUploadFile(
        name: 'overflow.png',
        size: 1,
        readAsBytes: () async {
          byteReads++;
          return _pixelBytes;
        },
        openRead: () {
          streamOpens++;
          return stream.stream;
        },
      );
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = () => setState(() {});
              return BeuiAttachmentUpload(
                controller: controller,
                onAcquisitionError: (_, _) => errors++,
              );
            },
          ),
        ),
      );
      await tester.pump();
      controller.add([
        BeuiAttachmentUploadItem(
          id: 'overflow',
          name: 'overflow.png',
          kind: BeuiAttachmentKind.image,
          size: 1,
          file: file,
        ),
      ]);
      await tester.pump();
      stream
        ..add(_pixelBytes)
        ..add(Uint8List(_previewLimit - _pixelBytes.length + 1));
      await tester.pump();

      expect(cancellations, 1);
      expect(byteReads, 0);
      expect(errors, 0);
      expect(find.byType(Image), findsNothing);
      rebuild();
      await tester.pump();
      expect(streamOpens, 1);
      expect(errors, 0);
      await stream.close();
      await streamDone;
      await _flushExternalStreamCleanup(tester);
    });

    testWidgets('queued file previews never overlap active reads', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      final first = StreamController<List<int>>();
      final firstDone = first.done;
      var firstOpens = 0;
      var secondOpens = 0;
      final files = [
        BeuiUploadFile(
          name: 'first.png',
          size: 1,
          readAsBytes: () async => throw StateError('unexpected byte read'),
          openRead: () {
            firstOpens++;
            return first.stream;
          },
        ),
        BeuiUploadFile(
          name: 'second.png',
          size: 1,
          readAsBytes: () async => throw StateError('unexpected byte read'),
          openRead: () {
            secondOpens++;
            return Stream<List<int>>.value(_pixelBytes);
          },
        ),
      ];
      await tester.pumpWidget(
        _app(BeuiAttachmentUpload(controller: controller)),
      );
      await tester.pump();
      controller.add([
        for (var i = 0; i < files.length; i++)
          BeuiAttachmentUploadItem(
            id: 'queued-$i',
            name: 'queued-$i.png',
            kind: BeuiAttachmentKind.image,
            size: files[i].size,
            file: files[i],
          ),
      ]);
      await tester.pump();
      expect(firstOpens, 1);
      expect(secondOpens, 0);

      first.add(_pixelBytes);
      await first.close();
      await firstDone;
      await _flushExternalStreamCleanup(tester);
      expect(secondOpens, 1);
    });

    testWidgets(
      'current stream failure reports once and rebuild does not retry',
      (tester) async {
        final errors = <Object>[];
        var streamOpens = 0;
        late void Function(VoidCallback) rebuild;
        final item = BeuiAttachmentUploadItem(
          id: 'failed-preview',
          name: 'failed.png',
          kind: BeuiAttachmentKind.image,
          size: 4,
          file: BeuiUploadFile(
            name: 'failed.png',
            size: 4,
            readAsBytes: () async => throw StateError('unexpected byte read'),
            openRead: () {
              streamOpens++;
              return Stream<List<int>>.error(StateError('preview read failed'));
            },
          ),
        );
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return BeuiAttachmentUpload(
                  value: [item],
                  onAcquisitionError: (error, _) => errors.add(error),
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(errors, hasLength(1));
        expect(errors.single.toString(), 'Bad state: preview read failed');
        rebuild(() {});
        await tester.pump();

        expect(streamOpens, 1);
        expect(errors, hasLength(1));
      },
    );

    testWidgets('replacement file identity rejects an older preview read', (
      tester,
    ) async {
      final releaseCancellation = Completer<void>();
      var oldReadCancelled = 0;
      final oldBytes = StreamController<List<int>>(
        onCancel: () {
          oldReadCancelled++;
          return releaseCancellation.future;
        },
      );
      final oldDone = oldBytes.done;
      final errors = <Object>[];
      var replacementOpens = 0;
      var item = BeuiAttachmentUploadItem(
        id: 'flower',
        name: 'flower.png',
        kind: BeuiAttachmentKind.image,
        size: _pixelBytes.length,
        file: BeuiUploadFile(
          name: 'flower.png',
          size: _pixelBytes.length,
          readAsBytes: () async => throw StateError('unexpected byte read'),
          openRead: () => oldBytes.stream,
        ),
      );
      late void Function(VoidCallback) update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiAttachmentUpload(
                value: [item],
                onAcquisitionError: (error, _) => errors.add(error),
              );
            },
          ),
        ),
      );
      await tester.pump();

      update(
        () => item = item.copyWith(
          file: BeuiUploadFile(
            name: 'flower.png',
            size: _pixelBytes.length,
            readAsBytes: () async => throw StateError('unexpected byte read'),
            openRead: () {
              replacementOpens++;
              return Stream<List<int>>.value(_pixelBytes);
            },
          ),
        ),
      );
      await tester.pump();
      expect(oldReadCancelled, 1);
      expect(replacementOpens, 0);
      releaseCancellation.complete();
      await oldBytes.close();
      await oldDone;
      await tester.pump();
      await tester.pump();

      expect(replacementOpens, 1);
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2400));
    });

    testWidgets('disposal waits silently and never starts queued previews', (
      tester,
    ) async {
      final releaseCancellation = Completer<void>();
      final errors = <Object>[];
      var successorOpens = 0;
      final firstStream = StreamController<List<int>>(
        onCancel: () => releaseCancellation.future,
      );
      final files = [
        BeuiUploadFile(
          name: 'active.png',
          size: 1,
          readAsBytes: () async => throw StateError('unexpected byte read'),
          openRead: () => firstStream.stream,
        ),
        BeuiUploadFile(
          name: 'queued.png',
          size: 4,
          readAsBytes: () async => throw StateError('unexpected byte read'),
          openRead: () {
            successorOpens++;
            return Stream<List<int>>.error(StateError('stale read'));
          },
        ),
      ];
      final items = [
        for (var index = 0; index < files.length; index++)
          BeuiAttachmentUploadItem(
            id: 'dispose-$index',
            name: files[index].name,
            kind: BeuiAttachmentKind.image,
            size: files[index].size,
            file: files[index],
          ),
      ];
      await tester.pumpWidget(
        _app(
          BeuiAttachmentUpload(
            value: items,
            onAcquisitionError: (error, _) => errors.add(error),
          ),
        ),
      );
      await tester.pump();
      expect(successorOpens, 0);

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(successorOpens, 0);
      releaseCancellation.completeError(
        StateError('stale cancellation failure'),
      );
      await tester.pump();
      await tester.pump();

      expect(successorOpens, 0);
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('removal cancels preview before the exiting row unmounts', (
      tester,
    ) async {
      var streamOpens = 0;
      var streamCancels = 0;
      var items = <BeuiAttachmentUploadItem>[
        BeuiAttachmentUploadItem(
          id: 'removed',
          name: 'removed.png',
          kind: BeuiAttachmentKind.image,
          size: 4,
          file: BeuiUploadFile(
            name: 'removed.png',
            size: 4,
            readAsBytes: () async => throw StateError('unexpected byte read'),
            openRead: () {
              streamOpens++;
              return StreamController<List<int>>(
                onCancel: () => streamCancels++,
              ).stream;
            },
          ),
        ),
      ];
      late void Function(VoidCallback) update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiAttachmentUpload(value: items);
            },
          ),
        ),
      );
      await tester.pump();
      expect(streamOpens, 1);

      update(() => items = []);
      await tester.pump();
      expect(streamCancels, 1);
      expect(find.text('removed.png'), findsOneWidget);
      update(() {});
      await tester.pump();

      expect(streamOpens, 1);
      expect(streamCancels, 1);
    });

    testWidgets('reduced motion keeps the upload lifecycle short', (
      tester,
    ) async {
      final controller = BeuiAttachmentUploadController();
      await tester.pumpWidget(
        _app(BeuiAttachmentUpload(controller: controller), reduce: true),
      );
      await tester.pump();
      controller.add([_candidate('small')]);
      await tester.pump();
      expect(find.byIcon(LucideIcons.check), findsNothing);
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
    });
  });
}

Future<void> _flushExternalStreamCleanup(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
  theme: BeuiTextTheme.trackingNormal(
    ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
  ),
  home: Scaffold(
    body: reduce
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child,
            ),
          )
        : child,
  ),
);

BeuiUploadFile _capability(String name, int size) => BeuiUploadFile(
  name: name,
  size: size,
  readAsBytes: () async => Uint8List(size),
  openRead: () => Stream<List<int>>.value(List<int>.filled(size, 0)),
);

BeuiAttachmentUploadItem _candidate(
  String id, {
  int size = 1,
  BeuiUploadFile? file,
}) => BeuiAttachmentUploadItem(id: id, name: '$id.txt', size: size, file: file);
