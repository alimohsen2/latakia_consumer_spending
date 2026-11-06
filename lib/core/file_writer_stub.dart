import 'dart:typed_data';

bool get requiresFileWriteAfterSave => false;

Future<void> writeBytesToFile(String path, Uint8List bytes) async {
  throw UnsupportedError('Writing to a local file is not supported.');
}
