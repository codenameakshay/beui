import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'upload_acquisition_capability.dart'
    show UploadFileCapability, UploadPickerOperation;

UploadPickerOperation pickBrowserUploadFiles({
  String? accept,
  required bool multiple,
}) {
  final operation = UploadPickerOperation();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = multiple;
  if (accept != null && accept.trim().isNotEmpty) input.accept = accept;
  input.style
    ..position = 'fixed'
    ..left = '-10000px'
    ..opacity = '0';
  late final JSFunction change;
  late final JSFunction cancel;
  void cleanup() {
    input.removeEventListener('change', change);
    input.removeEventListener('cancel', cancel);
    input.remove();
  }

  void finish(List<UploadFileCapability> files) {
    cleanup();
    operation.complete(files);
  }

  change = ((web.Event _) {
    if (operation.isCancelled) return;
    try {
      final selected = input.files;
      final files = <UploadFileCapability>[];
      if (selected != null) {
        for (var i = 0; i < selected.length; i++) {
          final file = selected.item(i);
          if (file != null) files.add(_webFile(file));
        }
      }
      finish(files);
    } catch (error, stackTrace) {
      cleanup();
      operation.completeError(error, stackTrace);
    }
  }).toJS;
  cancel = ((web.Event _) {
    if (!operation.isCancelled) finish(const []);
  }).toJS;
  operation.setCancelCallback(cleanup);
  try {
    input.addEventListener('change', change);
    input.addEventListener('cancel', cancel);
    final body = web.document.body;
    if (body == null) throw StateError('Document body is unavailable.');
    body.append(input);
    input.click();
  } catch (error, stackTrace) {
    cleanup();
    operation.completeError(error, stackTrace);
  }
  return operation;
}

Widget wrapUploadDropTarget({
  required bool enabled,
  required Widget child,
  required ValueChanged<bool> onDragChanged,
  required Future<void> Function(List<UploadFileCapability>) onFilesDropped,
  required ValueChanged<Object> onAcquisitionError,
}) => enabled
    ? _WebUploadDropTarget(
        onDragChanged: onDragChanged,
        onFilesDropped: onFilesDropped,
        onAcquisitionError: onAcquisitionError,
        child: child,
      )
    : child;

class _WebUploadDropTarget extends StatefulWidget {
  const _WebUploadDropTarget({
    required this.child,
    required this.onDragChanged,
    required this.onFilesDropped,
    required this.onAcquisitionError,
  });

  final Widget child;
  final ValueChanged<bool> onDragChanged;
  final Future<void> Function(List<UploadFileCapability>) onFilesDropped;
  final ValueChanged<Object> onAcquisitionError;

  @override
  State<_WebUploadDropTarget> createState() => _WebUploadDropTargetState();
}

class _WebUploadDropTargetState extends State<_WebUploadDropTarget> {
  static final Set<_WebUploadDropTargetState> _targets = {};
  static _WebUploadDropTargetState? _hoverRecipient;
  static int _nextId = 0;
  final int _id = _nextId++;
  final GlobalKey _key = GlobalKey();
  bool _disposed = false;
  late final JSFunction _over = ((web.Event event) {
    final recipient = _recipient(event);
    if (!identical(recipient, _hoverRecipient)) {
      _hoverRecipient?.widget.onDragChanged(false);
      _hoverRecipient = recipient;
      recipient?.widget.onDragChanged(true);
    }
    if (identical(recipient, this)) (event as web.DragEvent).preventDefault();
  }).toJS;
  late final JSFunction _leave = ((web.Event event) {
    if (!event.isA<web.DragEvent>()) return;
    final recipient = _recipient(event);
    if (!identical(recipient, _hoverRecipient)) {
      _hoverRecipient?.widget.onDragChanged(false);
      _hoverRecipient = recipient;
      recipient?.widget.onDragChanged(true);
    }
  }).toJS;
  late final JSFunction _drop = ((web.Event event) {
    final dragEvent = event as web.DragEvent;
    final recipient = _recipient(event);
    if (!identical(recipient, this) || dragEvent.dataTransfer == null) return;
    event.preventDefault();
    _hoverRecipient?.widget.onDragChanged(false);
    _hoverRecipient = null;
    unawaited(_handleDrop(dragEvent.dataTransfer!));
  }).toJS;

  @override
  void initState() {
    super.initState();
    _targets.add(this);
    web.document.addEventListener('dragover', _over);
    web.document.addEventListener('dragleave', _leave);
    web.document.addEventListener('drop', _drop);
  }

  double? _areaAt(Offset globalPosition) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final transform = box.getTransformTo(null)..invert();
    final localPosition = MatrixUtils.transformPoint(transform, globalPosition);
    if (!(Offset.zero & box.size).contains(localPosition)) return null;
    return box.size.width * box.size.height;
  }

  static _WebUploadDropTargetState? _recipient(web.Event event) {
    if (!event.isA<web.DragEvent>()) return null;
    final dragEvent = event as web.DragEvent;
    final position = Offset(
      dragEvent.clientX.toDouble(),
      dragEvent.clientY.toDouble(),
    );
    final candidates = <(_WebUploadDropTargetState, double)>[];
    for (final target in _targets) {
      final area = target._areaAt(position);
      if (area != null) {
        candidates.add((target, area));
      }
    }
    candidates.sort((a, b) {
      final byArea = a.$2.compareTo(b.$2);
      return byArea != 0 ? byArea : a.$1._id.compareTo(b.$1._id);
    });
    return candidates.isEmpty ? null : candidates.first.$1;
  }

  Future<void> _handleDrop(web.DataTransfer transfer) async {
    final files = <UploadFileCapability>[];
    try {
      for (var i = 0; i < transfer.items.length; i++) {
        final item = transfer.items[i];
        if (item.kind != 'file') continue;
        if ((item as _WebDataTransferItem).webkitGetAsEntry()?.isDirectory ??
            false) {
          continue;
        }
        final file = item.getAsFile();
        if (file == null) continue;
        files.add(_webFile(file));
      }
    } catch (error) {
      if (!_disposed) widget.onAcquisitionError(error);
      return;
    }
    if (!_disposed && files.isNotEmpty) await widget.onFilesDropped(files);
  }

  @override
  void dispose() {
    _disposed = true;
    if (identical(_hoverRecipient, this)) _hoverRecipient = null;
    _targets.remove(this);
    web.document.removeEventListener('dragover', _over);
    web.document.removeEventListener('dragleave', _leave);
    web.document.removeEventListener('drop', _drop);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

UploadFileCapability _webFile(web.File file) => UploadFileCapability(
  name: file.name,
  size: file.size,
  mimeType: file.type.isEmpty ? null : file.type,
  readBytes: () async => (await file.arrayBuffer().toDart).toDart.asUint8List(),
  openRead: () => _webOpenRead(file),
);

Stream<List<int>> _webOpenRead(web.File file) {
  web.ReadableStreamDefaultReader? reader;
  late final StreamController<List<int>> stream;
  var cancellationRequested = false;
  var finished = false;
  Future<void>? readerCancellation;
  Future<void>? pump;
  Completer<void>? resumed;

  Future<void> cancelReader() =>
      readerCancellation ??= Future<void>.sync(() async {
        final current = reader;
        if (current != null) await current.cancel().toDart;
      });

  void resume() {
    final waiting = resumed;
    resumed = null;
    waiting?.complete();
  }

  Future<void> readToStream() async {
    Object? failure;
    StackTrace? failureStack;
    try {
      reader = web.ReadableStreamDefaultReader(file.stream());
      while (!cancellationRequested) {
        while (stream.isPaused && !cancellationRequested) {
          await (resumed ??= Completer<void>()).future;
        }
        if (cancellationRequested) break;
        final result = await reader!.read().toDart;
        if (result.done) break;
        final chunk = result.value;
        if (!cancellationRequested && chunk != null) {
          stream.add((chunk as JSUint8Array).toDart);
        }
      }
    } catch (error, stackTrace) {
      if (!cancellationRequested) {
        failure = error;
        failureStack = stackTrace;
      }
    }

    if (cancellationRequested) return;
    try {
      await cancelReader();
    } catch (error, stackTrace) {
      failure ??= error;
      failureStack ??= stackTrace;
    } finally {
      try {
        reader?.releaseLock();
      } catch (error, stackTrace) {
        failure ??= error;
        failureStack ??= stackTrace;
      }
      finished = true;
    }

    if (cancellationRequested) return;
    if (failure != null) {
      stream.addError(failure, failureStack);
    }
    unawaited(stream.close());
  }

  stream = StreamController<List<int>>(
    sync: true,
    onListen: () {
      pump = readToStream();
    },
    onResume: resume,
    onCancel: () async {
      if (finished) return;
      cancellationRequested = true;
      resume();
      try {
        await cancelReader();
      } finally {
        await pump;
        if (!finished) {
          finished = true;
          reader?.releaseLock();
        }
      }
    },
  );
  return stream.stream;
}

extension type _WebDataTransferItem(web.DataTransferItem _)
    implements JSObject {
  external _WebFileSystemEntry? webkitGetAsEntry();
}

extension type _WebFileSystemEntry(JSObject _) implements JSObject {
  external bool get isDirectory;
}
