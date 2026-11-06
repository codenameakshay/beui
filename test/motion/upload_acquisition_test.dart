import 'package:beui/src/motion/attachment_upload.dart';
import 'package:beui/src/motion/upload_acquisition.dart';
import 'package:beui/src/motion/upload_acquisition_capability.dart';
import 'package:beui/src/motion/upload_mime_type.dart'
    show uploadMimeTypeForNativeFile;
import 'package:file_selector/file_selector.dart' as selector;
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart'
    as selector_platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NativeFileSelector extends selector_platform.FileSelectorPlatform {
  _NativeFileSelector(this.files);

  final List<selector.XFile> files;

  @override
  Future<List<selector.XFile>> openFiles({
    List<selector.XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => files;
}

class _TrackedNativeXFile extends selector.XFile {
  _TrackedNativeXFile(this.fileName, this.providerMimeType)
    : super.fromData(Uint8List.fromList([1, 2, 3]), name: fileName);

  final String fileName;
  final String? providerMimeType;
  int byteReads = 0;
  int streamOpens = 0;

  @override
  String get name => fileName;

  @override
  String? get mimeType => providerMimeType;

  @override
  Future<int> length() async => 3;

  @override
  Future<Uint8List> readAsBytes() async {
    byteReads++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    streamOpens++;
    return Stream.value(Uint8List.fromList([1, 2, 3]));
  }
}

void main() {
  test('native filename MIME fallback uses the approved extension table', () {
    const mimeTypes = <String, String>{
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'flac': 'audio/flac',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
    };

    for (final entry in mimeTypes.entries) {
      expect(
        uploadMimeTypeForNativeFile('upload.${entry.key}', null),
        entry.value,
      );
    }
  });

  test('native filename MIME fallback uses basename and ASCII case only', () {
    expect(
      uploadMimeTypeForNativeFile(r'C:\uploads\first.backup.PNG', null),
      'image/png',
    );
    expect(uploadMimeTypeForNativeFile('report.PdF', null), 'application/pdf');
    expect(uploadMimeTypeForNativeFile('.png', null), isNull);
    expect(uploadMimeTypeForNativeFile('report.', null), isNull);
    expect(uploadMimeTypeForNativeFile('README', null), isNull);
    expect(uploadMimeTypeForNativeFile('archive.unknown', null), isNull);
    expect(uploadMimeTypeForNativeFile('archive.ＰＮＧ', null), isNull);
  });

  test('nonblank native provider MIME is preserved verbatim', () {
    expect(
      uploadMimeTypeForNativeFile('picture.png', 'application/octet-stream'),
      'application/octet-stream',
    );
    expect(
      uploadMimeTypeForNativeFile('picture.png', ' application/custom '),
      ' application/custom ',
    );
    expect(uploadMimeTypeForNativeFile('picture.png', '  '), 'image/png');
  });

  testWidgets('native picker fallback classifies files without reading them', (
    tester,
  ) async {
    final originalSelector = selector_platform.FileSelectorPlatform.instance;
    final previousTarget = debugDefaultTargetPlatformOverride;
    final png = _TrackedNativeXFile('capture.PNG', null);
    final mp3 = _TrackedNativeXFile('voice.mp3', ' \t');
    selector_platform.FileSelectorPlatform.instance = _NativeFileSelector([
      png,
      mp3,
    ]);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    List<BeuiAttachmentUploadItem>? acceptedItems;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: BeuiAttachmentUpload(
            value: const [],
            onFilesAdded: (items, _) => acceptedItems = items,
          ),
        ),
      );
      await tester.tap(find.text('Drag and drop or browse files'));
      await tester.pump();
      await tester.pump();

      expect(acceptedItems?.map((item) => item.name), [
        'capture.PNG',
        'voice.mp3',
      ]);
      expect(acceptedItems?.map((item) => item.file?.mimeType), [
        'image/png',
        'audio/mpeg',
      ]);
      expect(acceptedItems?.map((item) => item.kind), [
        BeuiAttachmentKind.image,
        BeuiAttachmentKind.audio,
      ]);
      expect(png.byteReads, 0);
      expect(png.streamOpens, 0);
      expect(mp3.byteReads, 0);
      expect(mp3.streamOpens, 0);
    } finally {
      selector_platform.FileSelectorPlatform.instance = originalSelector;
      debugDefaultTargetPlatformOverride = previousTarget;
    }
  });

  test(
    'upload capability preserves metadata and defers repeatable reads',
    () async {
      var byteReads = 0;
      var streamReads = 0;
      final capability = UploadFileCapability(
        name: 'sample.pdf',
        size: 3,
        mimeType: 'application/pdf',
        readBytes: () async {
          byteReads++;
          return Uint8List.fromList([1, 2, 3]);
        },
        openRead: () {
          streamReads++;
          return Stream<List<int>>.value([1, 2, 3]);
        },
      );

      expect(capability.name, 'sample.pdf');
      expect(capability.size, 3);
      expect(capability.mimeType, 'application/pdf');
      expect(byteReads, 0);
      expect(streamReads, 0);

      expect(await capability.readBytes(), [1, 2, 3]);
      expect(await capability.readBytes(), [1, 2, 3]);
      expect(await capability.openRead().toList(), [
        <int>[1, 2, 3],
      ]);
      expect(await capability.openRead().toList(), [
        <int>[1, 2, 3],
      ]);
      expect(byteReads, 2);
      expect(streamReads, 2);
    },
  );

  test('picker hints normalize extensions and MIME types', () {
    final previousTarget = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final groups = uploadPickerTypeGroups(' .PDF, application/pdf ');
      expect(groups, hasLength(1));
      expect(groups.single, isA<selector.XTypeGroup>());
      expect(groups.single.extensions, ['pdf']);
      expect(groups.single.mimeTypes, ['application/pdf']);
      expect(uploadPickerTypeGroups('not a filter'), isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = previousTarget;
    }
  });

  test('unrepresentable picker hints fall back to an unfiltered chooser', () {
    final previousTarget = debugDefaultTargetPlatformOverride;
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(uploadPickerTypeGroups('.pdf,image/*'), isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(uploadPickerTypeGroups('.png,.custom'), isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = previousTarget;
    }
  });

  test('native wildcard MIME hint stays a MIME filter', () {
    final previousTarget = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final groups = uploadPickerTypeGroups('image/*');
      expect(groups.single.mimeTypes, ['image/*']);
      expect(groups.single.webWildCards, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = previousTarget;
    }
  });

  test('mobile drop acquisition is inert and leaves the tap target intact', () {
    final previousTarget = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      const child = SizedBox();
      final target = uploadDropTarget(
        enabled: true,
        child: child,
        onDragChanged: (_) {},
        onFilesDropped: (_) async {},
        onAcquisitionError: (_) {},
      );
      expect(identical(target, child), isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = previousTarget;
    }
  });

  test('cancelled picker operation suppresses a late file result', () async {
    final operation = UploadPickerOperation();
    var cleanupCount = 0;
    operation.setCancelCallback(() => cleanupCount++);

    final result = operation.result;
    operation.cancel();
    operation.complete([
      UploadFileCapability(
        name: 'late.pdf',
        size: 0,
        readBytes: () async => Uint8List(0),
        openRead: () => const Stream<List<int>>.empty(),
      ),
    ]);

    expect(await result, isEmpty);
    expect(operation.isCancelled, isTrue);
    expect(cleanupCount, 1);
  });

  test('completed picker operation exposes lazy file reads', () async {
    final operation = UploadPickerOperation();
    final result = operation.result;
    operation.complete([
      UploadFileCapability(
        name: 'ready.pdf',
        size: 2,
        readBytes: () async => Uint8List.fromList([9, 8]),
        openRead: () => Stream<List<int>>.value([9, 8]),
      ),
    ]);

    final files = await result;
    expect(files.single.name, 'ready.pdf');
    expect(await files.single.readBytes(), [9, 8]);
  });

  test('picker operation preserves acquisition errors', () async {
    final operation = UploadPickerOperation();
    final error = StateError('picker failed');
    final result = operation.result;
    operation.completeError(error);

    await expectLater(result, throwsA(same(error)));
  });

  test(
    'picker cancellation runs cleanup once and ignores late errors',
    () async {
      final operation = UploadPickerOperation();
      var cleanupCount = 0;
      operation.setCancelCallback(() => cleanupCount++);
      final result = operation.result;

      operation.cancel();
      operation.cancel();
      operation.completeError(StateError('late picker failure'));

      expect(await result, isEmpty);
      expect(cleanupCount, 1);
    },
  );
}
