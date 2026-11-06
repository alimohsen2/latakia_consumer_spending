import 'dart:io';
import 'dart:typed_data';

bool get requiresFileWriteAfterSave =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> writeBytesToFile(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}
