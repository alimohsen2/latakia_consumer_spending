import 'dart:typed_data';

import 'file_writer_stub.dart'
    if (dart.library.io) 'file_writer_io.dart' as implementation;

bool get requiresFileWriteAfterSave => implementation.requiresFileWriteAfterSave;

Future<void> writeBytesToFile(String path, Uint8List bytes) =>
    implementation.writeBytesToFile(path, bytes);
