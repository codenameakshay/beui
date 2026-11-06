import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart' as drag;

import 'upload_acquisition_capability.dart'
    show UploadFileCapability, UploadPickerOperation;
import 'upload_mime_type.dart' show uploadMimeTypeForNativeFile;

UploadPickerOperation pickBrowserUploadFiles({
  String? accept,
  required bool multiple,
}) {
  final operation = UploadPickerOperation();
  operation.completeError(UnsupportedError('Browser picker is unavailable.'));
  return operation;
}

Widget wrapUploadDropTarget({
  required bool enabled,
  required Widget child,
  required ValueChanged<bool> onDragChanged,
  required Future<void> Function(List<UploadFileCapability>) onFilesDropped,
  required ValueChanged<Object> onAcquisitionError,
}) {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.macOS &&
          defaultTargetPlatform != TargetPlatform.windows &&
          defaultTargetPlatform != TargetPlatform.linux)) {
    return child;
  }
  return _NativeUploadDropTarget(
    enabled: enabled,
    onDragChanged: onDragChanged,
    onFilesDropped: onFilesDropped,
    onAcquisitionError: onAcquisitionError,
    child: child,
  );
}

class _NativeUploadDropTarget extends StatefulWidget {
  const _NativeUploadDropTarget({
    required this.enabled,
    required this.child,
    required this.onDragChanged,
    required this.onFilesDropped,
    required this.onAcquisitionError,
  });

  final bool enabled;
  final Widget child;
  final ValueChanged<bool> onDragChanged;
  final Future<void> Function(List<UploadFileCapability>) onFilesDropped;
  final ValueChanged<Object> onAcquisitionError;

  @override
  State<_NativeUploadDropTarget> createState() =>
      _NativeUploadDropTargetState();
}

class _NativeUploadDropTargetState extends State<_NativeUploadDropTarget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return drag.DropRegion(
      formats: drag.Formats.standardFormats,
      onDropOver: (event) {
        final acceptsFile = event.session.items.any((item) {
          return item.canProvide(drag.Formats.fileUri) ||
              drag.Formats.standardFormats.whereType<drag.FileFormat>().any(
                item.canProvide,
              );
        });
        return acceptsFile ? drag.DropOperation.copy : drag.DropOperation.none;
      },
      onDropEnter: (_) {
        if (mounted && widget.enabled) widget.onDragChanged(true);
      },
      onDropLeave: (_) {
        if (mounted && widget.enabled) widget.onDragChanged(false);
      },
      onDropEnded: (_) {
        if (mounted && widget.enabled) widget.onDragChanged(false);
      },
      onPerformDrop: (event) async {
        if (!mounted || !widget.enabled) return;
        widget.onDragChanged(false);
        late final List<UploadFileCapability> files;
        try {
          files = await _nativeDropFiles(event);
        } catch (error) {
          if (mounted && widget.enabled) widget.onAcquisitionError(error);
          return;
        }
        if (mounted && widget.enabled && files.isNotEmpty) {
          await widget.onFilesDropped(files);
        }
      },
      child: widget.child,
    );
  }
}

Future<List<UploadFileCapability>> _nativeDropFiles(
  drag.PerformDropEvent event,
) async {
  final files = <UploadFileCapability>[];
  for (final item in event.session.items) {
    final reader = item.dataReader;
    if (reader == null) continue;
    if (!reader.canProvide(drag.Formats.fileUri)) {
      final hasVirtualFile = drag.Formats.standardFormats
          .whereType<drag.FileFormat>()
          .any(
            (format) => reader.canProvide(format) && reader.isVirtual(format),
          );
      if (hasVirtualFile) {
        throw StateError('Dropped virtual file did not provide a file URI.');
      }
      continue;
    }
    final uriCompleter = Completer<Uri?>();
    final errorCompleter = Completer<Object>();
    final progress = reader.getValue<Uri>(
      drag.Formats.fileUri,
      (uri) {
        if (!uriCompleter.isCompleted) uriCompleter.complete(uri);
      },
      onError: (error) {
        if (!errorCompleter.isCompleted) errorCompleter.complete(error);
      },
    );
    if (progress == null) continue;
    final finished = Completer<void>();
    void listen() {
      if (progress.fraction.value == 1 && !finished.isCompleted) {
        finished.complete();
      }
    }

    progress.fraction.addListener(listen);
    listen();
    try {
      await Future.any<void>([
        finished.future,
        errorCompleter.future.then<void>((error) => throw error),
      ]);
      final uri = await uriCompleter.future;
      if (uri == null || uri.scheme != 'file') {
        throw StateError('Dropped item did not provide a file URI.');
      }
      final file = File.fromUri(uri);
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.file) continue;
      final stat = await FileStat.stat(file.path);
      final name = uri.pathSegments.isEmpty ? file.path : uri.pathSegments.last;
      files.add(
        UploadFileCapability(
          name: name,
          size: stat.size,
          mimeType: uploadMimeTypeForNativeFile(name, null),
          readBytes: file.readAsBytes,
          openRead: file.openRead,
        ),
      );
    } finally {
      progress.fraction.removeListener(listen);
    }
  }
  return files;
}
