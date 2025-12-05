import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:path/path.dart' as p;

class MetadataService {
  static String getAppNameFromPath(String path) {
    if (path.isEmpty) return 'App';
    return p.basenameWithoutExtension(path);
  }

  static Future<String?> fetchPageTitle(String url) async {
    try {
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        return document.head?.querySelector('title')?.text;
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  static Future<String?> fetchFaviconBase64(String url) async {
    try {
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      final uri = Uri.parse(url);

      // Try Google Favicon Service first (High reliability)
      final googleFavicon =
          'https://www.google.com/s2/favicons?sz=64&domain_url=${uri.host}';
      final response = await http.get(Uri.parse(googleFavicon));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return base64Encode(response.bodyBytes);
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }
}
