import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';

Future<void> writeBytesToFile(String path, Uint8List bytes) async {
  final file = File(path);
  await file.writeAsBytes(bytes);
}

Future<bool> openFilePath(String path) async {
  if (!File(path).existsSync()) {
    return false;
  }
  final result = await OpenFile.open(path);
  return result.type == ResultType.done;
}
