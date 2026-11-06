import 'dart:async';

import 'package:beui/src/motion/file_upload.dart';
import 'package:beui/src/motion/upload_file.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';
import 'package:beui/src/tokens/icons.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileSelector extends FileSelectorPlatform {
  Completer<List<XFile>>? filesResult;
  Completer<XFile?>? fileResult;
  Object? failure;
  int openFilesCalls = 0;
  int openFileCalls = 0;
  List<XTypeGroup>? acceptedFileTypes;
  List<XTypeGroup>? acceptedFilesTypes;

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) {
    openFilesCalls++;
    acceptedFilesTypes = acceptedTypeGroups;
    if (failure case final error?) return Future.error(error);
    return (filesResult ??= Completer<List<XFile>>()).future;
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) {
    openFileCalls++;
    acceptedFileTypes = acceptedTypeGroups;
    if (failure case final error?) return Future.error(error);
    return (fileResult ??= Completer<XFile?>()).future;
  }
}

class _TrackedXFile extends XFile {
  _TrackedXFile(this.bytes, {required this.fileName, this.contentType})
    : super.fromData(bytes, name: fileName, mimeType: contentType);

  final Uint8List bytes;
  final String fileName;
  final String? contentType;
  int byteReads = 0;
  int streamOpens = 0;

  @override
  String get name => fileName;

  @override
  String? get mimeType => contentType;

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

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Padding(padding: const EdgeInsets.all(16), child: child);
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

_TrackedXFile _file(String name, List<int> bytes) => _TrackedXFile(
  Uint8List.fromList(bytes),
  fileName: name,
  contentType: 'application/octet-stream',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _originalSelector = FileSelectorPlatform.instance;
  setUp(() {
    _selector = _FileSelector();
    FileSelectorPlatform.instance = _selector;
  });
  tearDown(() => FileSelectorPlatform.instance = _originalSelector);

  group('BeuiFileUpload v3.1 acquisition', () {
    testWidgets('proposes uploading metadata before lazy raw file callbacks', (
      tester,
    ) async {
      final file = _file('notes.txt', [0x62, 0x65, 0x75, 0x69]);

      final order = <String>[];
      List<BeuiFileUploadItem>? proposed;
      List<BeuiUploadFile>? rawFiles;
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            onValueChange: (items) {
              order.add('value');
              proposed = items;
            },
            onFilesAdded: (items, files) {
              order.add('added');
              expect(items.map((item) => item.name), ['notes.txt']);
              expect(file.byteReads, 0);
              expect(file.streamOpens, 0);
              rawFiles = files;
            },
          ),
        ),
      );

      await tester.tap(find.text('Browse files'));
      expect(_selector.openFilesCalls, 1);
      await tester.pump();
      _selector.filesResult!.complete([file]);
      await tester.pump();
      await tester.pump();

      expect(order, ['value', 'added']);
      expect(proposed, hasLength(1));
      expect(proposed!.single.name, 'notes.txt');
      expect(proposed!.single.status, BeuiFileUploadStatus.uploading);
      expect(proposed!.single.progress, 0);
      expect(proposed!.single.file, isNotNull);
      expect(find.byIcon(LucideIcons.file_text), findsOneWidget);
      expect(rawFiles, hasLength(1));
      expect(identical(proposed!.single.file, rawFiles!.single), isTrue);
      expect(rawFiles!.single.name, 'notes.txt');
      expect(await rawFiles!.single.readAsBytes(), [0x62, 0x65, 0x75, 0x69]);
      expect(await rawFiles!.single.readAsBytes(), [0x62, 0x65, 0x75, 0x69]);
      expect(await proposed!.single.file!.openRead().toList(), [
        [0x62, 0x65, 0x75, 0x69],
      ]);
      expect(await proposed!.single.file!.openRead().toList(), [
        [0x62, 0x65, 0x75, 0x69],
      ]);
      expect(file.byteReads, 2);
      expect(file.streamOpens, 2);
    });

    testWidgets('slices by remaining count before retaining size rejections', (
      tester,
    ) async {
      final tooLarge = _file('large.bin', [1, 2, 3]);
      final accepted = _file('small.bin', [4]);
      final overflow = _file('tail.bin', [5]);

      final events = <String>[];
      List<BeuiFileUploadItem>? proposal;
      List<BeuiFileUploadItem>? added;
      List<BeuiUploadFile>? rawAdded;
      List<BeuiFileUploadItem>? rejected;
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            maxFiles: 2,
            maxFileSize: 2,
            onValueChange: (items) {
              events.add('value');
              proposal = items;
            },
            onFilesAdded: (items, files) {
              events.add('added');
              added = items;
              rawAdded = files;
            },
            onRejected: (items) {
              events.add('rejected');
              rejected = items;
            },
          ),
        ),
      );

      await tester.tap(find.text('Browse files'));
      await tester.pump();
      _selector.filesResult!.complete([tooLarge, accepted, overflow]);
      await tester.pump();
      await tester.pump();

      expect(proposal!.map((item) => item.name), ['large.bin', 'small.bin']);
      expect(added!.map((item) => item.name), ['small.bin']);
      expect(rawAdded!.map((file) => file.name), ['small.bin']);
      expect(rejected!.map((item) => item.name), ['large.bin']);
      expect(events, ['value', 'added', 'rejected']);
      expect(find.text('tail.bin'), findsNothing);
    });

    testWidgets('rechecks the current controlled limit after picker await', (
      tester,
    ) async {
      final file = _file('late.txt', [7]);
      final response = _selector.filesResult = Completer<List<XFile>>();

      var changes = 0;
      var additions = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            value: const [
              BeuiFileUploadItem(id: 'first', name: 'first.txt', size: 1),
            ],
            maxFiles: 2,
            onValueChange: (_) => changes++,
            onFilesAdded: (_, _) => additions++,
          ),
        ),
      );
      await tester.tap(find.text('Browse files'));
      await tester.pump();
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            value: const [
              BeuiFileUploadItem(id: 'first', name: 'first.txt', size: 1),
              BeuiFileUploadItem(id: 'second', name: 'second.txt', size: 1),
            ],
            maxFiles: 2,
            onValueChange: (_) => changes++,
            onFilesAdded: (_, _) => additions++,
          ),
        ),
      );
      response.complete([file]);
      await tester.pump();
      await tester.pump();

      expect(changes, 0);
      expect(additions, 0);
      expect(find.text('Upload limit reached'), findsOneWidget);
    });

    testWidgets('does not ingest a result after the owner disables the queue', (
      tester,
    ) async {
      final file = _file('disabled-late.txt', [7]);
      final response = _selector.filesResult = Completer<List<XFile>>();

      var changes = 0;
      var additions = 0;
      var errors = 0;
      Widget upload({required bool disabled}) => _wrap(
        BeuiFileUpload(
          disabled: disabled,
          onValueChange: (_) => changes++,
          onFilesAdded: (_, _) => additions++,
          onAcquisitionError: (_, _) => errors++,
        ),
      );

      await tester.pumpWidget(upload(disabled: false));
      await tester.tap(find.text('Browse files'));
      await tester.pump();
      await tester.pumpWidget(upload(disabled: true));
      response.complete([file]);
      await tester.pump();
      await tester.pump();

      expect(changes, 0);
      expect(additions, 0);
      expect(errors, 0);
    });

    testWidgets('does not retain a rejected controlled proposal', (
      tester,
    ) async {
      final file = _file('retry.txt', [1]);

      var proposals = 0;
      final proposalLengths = <int>[];
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            value: const [],
            maxFiles: 2,
            onValueChange: (items) {
              proposals++;
              proposalLengths.add(items.length);
            },
          ),
        ),
      );

      await tester.tap(find.text('Browse files'));
      await tester.pump();
      _selector.filesResult!.complete([file]);
      await tester.pump();
      _selector.filesResult = Completer<List<XFile>>();
      await tester.tap(find.text('Browse files'));
      await tester.pump();
      _selector.filesResult!.complete([file]);
      await tester.pump();

      expect(proposals, 2);
      expect(proposalLengths, [1, 1]);
      expect(find.text('retry.txt'), findsNothing);
    });

    testWidgets('supersedes a picker and ignores its late result', (
      tester,
    ) async {
      final oldFile = _file('old-result.txt', [1]);
      final newFile = _file('new-result.txt', [2]);
      final oldResponse = Completer<List<XFile>>();
      final newResponse = Completer<List<XFile>>();

      var additions = 0;
      await tester.pumpWidget(
        _wrap(BeuiFileUpload(onFilesAdded: (_, _) => additions++)),
      );
      _selector.filesResult = oldResponse;
      await tester.tap(find.text('Browse files'));
      await tester.pump();
      _selector.filesResult = newResponse;
      await tester.tap(find.text('Browse files'));
      await tester.pump();
      expect(_selector.openFilesCalls, 2);

      oldResponse.complete([oldFile]);
      await tester.pump();
      await tester.pump();
      expect(additions, 0);

      newResponse.complete([newFile]);
      await tester.pump();
      await tester.pump();
      expect(additions, 1);
      expect(find.text('old-result.txt'), findsNothing);
      expect(find.text('new-result.txt'), findsOneWidget);
    });

    testWidgets('cancelled selection is silent and the picker can reopen', (
      tester,
    ) async {
      final file = _file('reopened.txt', [8]);

      var changes = 0;
      var additions = 0;
      var errors = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            onValueChange: (_) => changes++,
            onFilesAdded: (_, _) => additions++,
            onAcquisitionError: (_, _) => errors++,
          ),
        ),
      );

      await tester.tap(find.text('Browse files'));
      await tester.pump();
      _selector.filesResult!.complete([]);
      await tester.pump();
      expect(changes, 0);
      expect(additions, 0);
      expect(errors, 0);

      _selector.filesResult = Completer<List<XFile>>();
      await tester.tap(find.text('Browse files'));
      await tester.pump();
      _selector.filesResult!.complete([file]);
      await tester.pump();
      await tester.pump();
      expect(_selector.openFilesCalls, 2);
      expect(changes, 1);
      expect(additions, 1);
      expect(errors, 0);
      expect(find.text('reopened.txt'), findsOneWidget);
    });

    testWidgets('reports picker failures without proposing queue changes', (
      tester,
    ) async {
      final failure = StateError('picker-failed');
      _selector.failure = failure;

      final errors = <Object>[];
      var changes = 0;
      var additions = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            onValueChange: (_) => changes++,
            onFilesAdded: (_, _) => additions++,
            onAcquisitionError: (error, _) => errors.add(error),
          ),
        ),
      );
      await tester.tap(find.text('Browse files'));
      await tester.pump();
      await tester.pump();

      expect(errors, hasLength(1));
      expect(errors.single, same(failure));
      expect(changes, 0);
      expect(additions, 0);
    });

    testWidgets('consumer callback failures are not acquisition failures', (
      tester,
    ) async {
      final file = _file('consumer-error.txt', [3]);
      final callbackFailure = StateError('consumer callback failed');
      var acquisitionErrors = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            onValueChange: (_) => throw callbackFailure,
            onAcquisitionError: (_, _) => acquisitionErrors++,
          ),
        ),
      );
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        await tester.tap(find.text('Browse files'));
        await tester.pump();
        _selector.filesResult!.complete([file]);
        await tester.pump();
      }, (error, _) => uncaught.add(error));

      expect(uncaught, [same(callbackFailure)]);
      expect(acquisitionErrors, 0);
    });

    testWidgets('Android policy stays tap-to-pick with the single-file hint', (
      tester,
    ) async {
      final file = _file('single.txt', [9]);
      // The override checks widget policy only, not native Android support.
      final previousTarget = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        List<BeuiFileUploadItem>? proposal;
        await tester.pumpWidget(
          _wrap(
            BeuiFileUpload(
              accept: '.txt',
              multiple: false,
              onValueChange: (items) => proposal = items,
            ),
          ),
        );
        await tester.tap(find.text('Browse files'));
        expect(_selector.openFileCalls, 1);
        expect(_selector.openFilesCalls, 0);
        expect(_selector.acceptedFileTypes!.single.extensions, ['txt']);
        _selector.fileResult!.complete(file);
        await tester.pump();

        expect(proposal!.map((item) => item.name), ['single.txt']);
      } finally {
        debugDefaultTargetPlatformOverride = previousTarget;
      }
    });

    testWidgets('suppresses a late picker result after disposal', (
      tester,
    ) async {
      final file = _file('late.txt', [7]);
      final response = _selector.filesResult = Completer<List<XFile>>();

      var changes = 0;
      var additions = 0;
      var errors = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            onValueChange: (_) => changes++,
            onFilesAdded: (_, _) => additions++,
            onAcquisitionError: (_, _) => errors++,
          ),
        ),
      );
      await tester.tap(find.text('Browse files'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete([file]);
      await tester.pump();
      await tester.pump();

      expect(changes, 0);
      expect(additions, 0);
      expect(errors, 0);
    });

    testWidgets('onBrowse exclusively overrides the built-in picker', (
      tester,
    ) async {
      var browseCalls = 0;
      var acquisitionErrors = 0;

      await tester.pumpWidget(
        _wrap(
          BeuiFileUpload(
            onBrowse: () => browseCalls++,
            onAcquisitionError: (_, _) => acquisitionErrors++,
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.tap(find.text('Browse files'));

      expect(browseCalls, 2);
      expect(_selector.openFileCalls, 0);
      expect(_selector.openFilesCalls, 0);
      expect(acquisitionErrors, 0);
    });

    testWidgets('disabled dropzone cannot activate by keyboard', (
      tester,
    ) async {
      var browseCalls = 0;
      await tester.pumpWidget(
        _wrap(BeuiFileUpload(disabled: true, onBrowse: () => browseCalls++)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.tap(find.text('Browse files'), warnIfMissed: false);

      expect(browseCalls, 0);
    });

    testWidgets('reduced motion keeps the browse target usable', (
      tester,
    ) async {
      var browseCalls = 0;
      await tester.pumpWidget(
        _wrap(BeuiFileUpload(onBrowse: () => browseCalls++), reduce: true),
      );
      await tester.tap(find.text('Browse files'));
      await tester.pump();

      expect(browseCalls, 1);
      expect(tester.takeException(), isNull);
    });

    test('copyWith preserves or explicitly clears the file capability', () {
      final file = BeuiUploadFile(
        name: 'notes.txt',
        size: 2,
        readAsBytes: () async => Uint8List.fromList([1, 2]),
        openRead: () => Stream<List<int>>.value([1, 2]),
      );
      const item = BeuiFileUploadItem(id: 'notes', name: 'notes.txt', size: 2);

      expect(
        item.copyWith(status: BeuiFileUploadStatus.uploading).file,
        isNull,
      );
      expect(
        item
            .copyWith(file: file)
            .copyWith(status: BeuiFileUploadStatus.success)
            .file,
        same(file),
      );
      expect(item.copyWith(file: file).copyWith(clearFile: true).file, isNull);
    });
  });
}
