import 'api_discovery_io.dart' if (dart.library.html) 'api_discovery_web.dart'
    as impl;

Future<String?> discoverBaseUrl(String currentBaseUrl) {
  return impl.discoverBaseUrl(currentBaseUrl);
}

