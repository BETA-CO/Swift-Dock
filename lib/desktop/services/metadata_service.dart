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

  static Future<String?> fetchAppIcon(String path) async {
    try {
      if (!Platform.isWindows) return null;

      final tempDir = Directory.systemTemp.createTempSync();
      final iconPath = p.join(tempDir.path, 'icon.png');

      // PowerShell script to extract icon
      final script =
          '''
      try {
        Add-Type -AssemblyName System.Drawing
        \$icon = [System.Drawing.Icon]::ExtractAssociatedIcon('${path.replaceAll("'", "''")}')
        if (\$icon -ne \$null) {
          \$bitmap = \$icon.ToBitmap()
          \$bitmap.Save('$iconPath', [System.Drawing.Imaging.ImageFormat]::Png)
          \$bitmap.Dispose()
          \$icon.Dispose()
        }
      } catch {
        // Ignore errors
      }
      ''';

      await Process.run('powershell', ['-c', script]);

      final iconFile = File(iconPath);
      if (await iconFile.exists()) {
        final bytes = await iconFile.readAsBytes();
        // cleanup
        try {
          // ignore: unused_local_variable
          final _ = tempDir.delete(recursive: true);
        } catch (_) {}

        return base64Encode(bytes);
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }
}
