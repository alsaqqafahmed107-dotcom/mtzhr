import 'platform_info_io.dart' if (dart.library.html) 'platform_info_web.dart'
    as impl;

bool get isAndroid => impl.isAndroid;
bool get isIOS => impl.isIOS;
bool get isWindows => impl.isWindows;
bool get isMacOS => impl.isMacOS;
bool get isLinux => impl.isLinux;
