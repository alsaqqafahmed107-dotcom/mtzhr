import 'dart:typed_data';

Future<void> writeBytesToFile(String path, Uint8List bytes) async {
  throw UnsupportedError('File writing is not supported on Web');
}

Future<bool> openFilePath(String path) async {
  return false;
}

