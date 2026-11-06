import 'package:flutter/widgets.dart';
import 'upload_acquisition_capability.dart'
    show UploadFileCapability, UploadPickerOperation;

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
}) => child;
