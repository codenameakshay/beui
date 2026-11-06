import 'package:flutter/foundation.dart';

/// Immutable metadata and lazy access to the contents of an uploaded file.
///
/// Reads are lazy and may be repeated. Consumers that need the file after the
/// widget that supplied it is disposed must retain this value themselves.
/// This capability owns no path, URL, or byte buffer; its callbacks define how
/// the contents are obtained.
@immutable
final class BeuiUploadFile {
  /// Creates a file descriptor without reading its contents.
  const BeuiUploadFile({
    required this.name,
    required this.size,
    required this.readAsBytes,
    required this.openRead,
    this.mimeType,
  });

  /// File name supplied by the consumer's acquisition mechanism.
  final String name;

  /// File size in bytes.
  final int size;

  /// Lazily reads the file contents as bytes. Each call may perform a new read.
  final Future<Uint8List> Function() readAsBytes;

  /// Lazily opens a byte stream. Each call may open a new stream.
  final Stream<List<int>> Function() openRead;

  /// Optional MIME type supplied by the consumer's acquisition mechanism.
  final String? mimeType;
}
