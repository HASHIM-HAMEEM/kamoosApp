// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final key = await _readEnvKey();
  if (key == null || key.isEmpty) {
    print('Gemini API key is missing in .env');
    exitCode = 1;
    return;
  }

  final client = HttpClient();
  try {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$key',
    );
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text': 'اختبر استجابة النموذج في جملة عربية قصيرة.'
            }
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 64,
        'temperature': 0.2,
      }
    }));

    final response = await request.close();
    final payload = await response.transform(utf8.decoder).join();
    if (response.statusCode == 200) {
      print('Gemini API call succeeded.');
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates.first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        final text = parts != null && parts.isNotEmpty ? parts.first['text'] as String? : null;
        if (text != null) {
          final preview = text.length > 160 ? text.substring(0, 160) + '…' : text;
          print('Sample response: $preview');
        }
      }
    } else {
      print('Gemini API call failed with status ${response.statusCode}.');
      print('Response body: $payload');
      exitCode = response.statusCode;
    }
  } finally {
    client.close(force: true);
  }
}

Future<String?> _readEnvKey() async {
  final file = File('.env');
  if (!await file.exists()) {
    return null;
  }
  final lines = await file.readAsLines();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('GEMINI_API_KEY=')) {
      return trimmed.substring('GEMINI_API_KEY='.length);
    }
  }
  return null;
}
