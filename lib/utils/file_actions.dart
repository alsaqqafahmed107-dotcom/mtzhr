import 'dart:typed_data';

import 'file_actions_io.dart' if (dart.library.html) 'file_actions_web.dart'
    as impl;

Future<void> writeBytesToFile(String path, Uint8List bytes) {
  return impl.writeBytesToFile(path, bytes);
}

Future<bool> openFilePath(String path) {
  return impl.openFilePath(path);
}

