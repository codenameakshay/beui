import 'dart:async';
import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'upload_acquisition_capability.dart'
    show UploadFileCapability, UploadPickerOperation;
import 'upload_mime_type.dart' show uploadMimeTypeForNativeFile;
import 'upload_acquisition_stub.dart'
    if (dart.library.io) 'upload_acquisition_io.dart'
    if (dart.library.js_interop) 'upload_acquisition_web.dart'
    as platform;

UploadPickerOperation pickUploadFiles({
  String? accept,
  required bool multiple,
}) {
  if (kIsWeb) {
    return platform.pickBrowserUploadFiles(accept: accept, multiple: multiple);
  }
  final operation = UploadPickerOperation();
  unawaited(_acquireNativeFiles(operation, accept, multiple));
  return operation;
}

Future<void> _acquireNativeFiles(
  UploadPickerOperation operation,
  String? accept,
  bool multiple,
) async {
  try {
    final types = uploadPickerTypeGroups(accept);
    final picked = multiple
        ? await selector.openFiles(acceptedTypeGroups: types)
        : [?await selector.openFile(acceptedTypeGroups: types)];
    if (operation.isCancelled) return;
    final files = <UploadFileCapability>[];
    for (final file in picked) {
      if (operation.isCancelled) return;
      files.add(await _fromXFile(file));
    }
    operation.complete(files);
  } catch (error, stackTrace) {
    operation.completeError(error, stackTrace);
  }
}

List<selector.XTypeGroup> uploadPickerTypeGroups(String? accept) {
  if (accept == null || accept.trim().isEmpty) return const [];
  final extensions = <String>[];
  final mimeTypes = <String>[];
  final wildcards = <String>[];
  final uniformTypeIdentifiers = <String>[];
  var hasUnrepresentableToken = false;
  for (final raw in accept.split(',')) {
    final token = raw.trim().toLowerCase();
    if (RegExp(r'^\.[a-z0-9][a-z0-9._+-]*$').hasMatch(token)) {
      extensions.add(token.substring(1));
    } else if (RegExp(
      r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$',
    ).hasMatch(token)) {
      mimeTypes.add(token);
    } else if (RegExp(r'^[a-z0-9!#$&^_.+-]+/\*$').hasMatch(token)) {
      wildcards.add(token);
    } else {
      hasUnrepresentableToken = true;
    }
  }
  if (hasUnrepresentableToken) return const [];
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    const extensionTypes = <String, String>{
      'gif': 'com.compuserve.gif',
      'jpeg': 'public.jpeg',
      'jpg': 'public.jpeg',
      'pdf': 'com.adobe.pdf',
      'png': 'public.png',
      'heic': 'public.heic',
      'heif': 'public.heif',
    };
    const mimeTypesToUti = <String, String>{
      'image/*': 'public.image',
      'audio/*': 'public.audio',
      'video/*': 'public.movie',
      'application/pdf': 'com.adobe.pdf',
      'image/gif': 'com.compuserve.gif',
      'image/jpeg': 'public.jpeg',
      'image/png': 'public.png',
    };
    final allTokens = [...extensions, ...mimeTypes, ...wildcards];
    uniformTypeIdentifiers.addAll(
      extensions.map((ext) => extensionTypes[ext]).nonNulls,
    );
    uniformTypeIdentifiers.addAll(
      [...mimeTypes, ...wildcards].map((mime) => mimeTypesToUti[mime]).nonNulls,
    );
    if (uniformTypeIdentifiers.length != allTokens.length) return const [];
    return [
      selector.XTypeGroup(uniformTypeIdentifiers: uniformTypeIdentifiers),
    ];
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    if (mimeTypes.isNotEmpty || wildcards.isNotEmpty) return const [];
  } else if (!kIsWeb) {
    mimeTypes.addAll(wildcards);
    wildcards.clear();
  }
  if (extensions.isEmpty && mimeTypes.isEmpty && wildcards.isEmpty) {
    return const [];
  }
  return [
    selector.XTypeGroup(
      extensions: extensions.isEmpty ? null : extensions,
      mimeTypes: mimeTypes.isEmpty ? null : mimeTypes,
      webWildCards: wildcards.isEmpty ? null : wildcards,
    ),
  ];
}

Future<UploadFileCapability> _fromXFile(selector.XFile file) async =>
    UploadFileCapability(
      name: file.name,
      size: await file.length(),
      mimeType: uploadMimeTypeForNativeFile(file.name, file.mimeType),
      readBytes: file.readAsBytes,
      openRead: file.openRead,
    );

Widget uploadDropTarget({
  required bool enabled,
  required Widget child,
  required ValueChanged<bool> onDragChanged,
  required Future<void> Function(List<UploadFileCapability>) onFilesDropped,
  required ValueChanged<Object> onAcquisitionError,
}) => platform.wrapUploadDropTarget(
  enabled: enabled,
  child: child,
  onDragChanged: onDragChanged,
  onFilesDropped: onFilesDropped,
  onAcquisitionError: onAcquisitionError,
);
