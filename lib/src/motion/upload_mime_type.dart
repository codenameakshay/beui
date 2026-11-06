const _uploadMimeTypesByExtension = <String, String>{
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

String? uploadMimeTypeForNativeFile(String name, String? providerMimeType) {
  if (providerMimeType != null && providerMimeType.trim().isNotEmpty) {
    return providerMimeType;
  }

  final basenameStart = name.lastIndexOf('/') > name.lastIndexOf('\\')
      ? name.lastIndexOf('/') + 1
      : name.lastIndexOf('\\') + 1;
  final basename = name.substring(basenameStart);
  final extensionStart = basename.lastIndexOf('.');
  if (extensionStart <= 0 || extensionStart == basename.length - 1) {
    return null;
  }

  final extension = String.fromCharCodes(
    basename.codeUnits.skip(extensionStart + 1).map((unit) {
      return unit >= 0x41 && unit <= 0x5a ? unit + 0x20 : unit;
    }),
  );
  return _uploadMimeTypesByExtension[extension];
}
