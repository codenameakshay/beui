import 'dart:async';

import 'package:flutter/foundation.dart';

@immutable
final class UploadFileCapability {
  const UploadFileCapability({
    required this.name,
    required this.size,
    required this.readBytes,
    required this.openRead,
    this.mimeType,
  });

  final String name;
  final int size;
  final String? mimeType;
  final Future<Uint8List> Function() readBytes;
  final Stream<List<int>> Function() openRead;
}

final class UploadPickerOperation {
  UploadPickerOperation();

  final Completer<List<UploadFileCapability>> _result =
      Completer<List<UploadFileCapability>>();
  bool _cancelled = false;
  void Function()? _onCancel;

  Future<List<UploadFileCapability>> get result => _result.future;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_result.isCompleted || _cancelled) return;
    _cancelled = true;
    final onCancel = _onCancel;
    _onCancel = null;
    onCancel?.call();
    _result.complete(const []);
  }

  void complete(List<UploadFileCapability> files) {
    if (!_result.isCompleted && !_cancelled) {
      _onCancel = null;
      _result.complete(files);
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_result.isCompleted && !_cancelled) {
      _onCancel = null;
      _result.completeError(error, stackTrace);
    }
  }

  void setCancelCallback(void Function() callback) {
    if (_result.isCompleted) return;
    _onCancel = callback;
    if (_cancelled) callback();
  }
}
