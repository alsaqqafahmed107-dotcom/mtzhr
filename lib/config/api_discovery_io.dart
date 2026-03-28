import 'dart:io';

Future<String?> discoverBaseUrl(String currentBaseUrl) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    final request = await client.postUrl(Uri.parse(currentBaseUrl));

    request.headers.set(
      'User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    );
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request.write('{}');

    final response = await request.close();

    if (response.statusCode >= 300 && response.statusCode < 400) {
      var location = response.headers['location']?.first;
      if (location != null && location.isNotEmpty) {
        if (location.endsWith('/')) {
          location = location.substring(0, location.length - 1);
        }
        return location;
      }
      return null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return currentBaseUrl;
    }

    return null;
  } catch (_) {
    return null;
  }
}

