import 'package:flutter/foundation.dart';

import 'platform_info.dart' as platform;

class PlatformHelper {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => platform.isAndroid;
  static bool get isIOS => platform.isIOS;
  static bool get isWindows => platform.isWindows;
  static bool get isMacOS => platform.isMacOS;
  static bool get isLinux => platform.isLinux;

  static bool get supportsLocalAuth => !isWeb;
  static bool get supportsLocalNotifications => !isWeb;
  static bool get supportsMlKitFaceDetection => !isWeb;
  static bool get supportsOpenFile => !isWeb;
}
