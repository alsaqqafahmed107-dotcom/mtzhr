import 'dart:typed_data';

import 'file_bytes_io.dart' if (dart.library.html) 'file_bytes_web.dart' as impl;

Future<Uint8List> readBytesFromPath(String path) {
  return impl.readBytesFromPath(path);
}

