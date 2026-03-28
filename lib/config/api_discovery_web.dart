import 'package:http/http.dart' as http;

Future<String?> discoverBaseUrl(String currentBaseUrl) async {
  try {
    // على Web نتحقق فقط إذا الخادم يرد
    final response = await http
        .get(Uri.parse('$currentBaseUrl/api/values'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode >= 200 && response.statusCode < 400) {
      return currentBaseUrl;
    }
    return null;
  } catch (_) {
    return null; // CORS أو الخادم مش شغال
  }
}
