import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/word.dart';

class ApiService {
  final String? apiKey;
  final String modelName;
  final http.Client _client;

  // Cache to store API responses (in-memory cache)
  final Map<String, Word> _cache = {};

  // Pending requests to prevent duplicate API calls
  final Map<String, Future<Word?>> _pendingRequests = {};

  // Request timeout duration
  static const Duration _requestTimeout = Duration(seconds: 30);

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(milliseconds: 500);

  ApiService({this.apiKey, String? modelName, http.Client? client})
      : modelName = (modelName != null && modelName.trim().isNotEmpty)
            ? modelName.trim()
            : 'gemini-2.0-flash-exp',
        _client = client ?? http.Client() {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('API key is required for Gemini service');
    }
    debugPrint('✨ ApiService initialized with model: $modelName');
  }

  /// Clear the cache (useful for testing or manual refresh)
  void clearCache() {
    _cache.clear();
    debugPrint('🗑️  Cache cleared');
  }

  /// Get cache size
  int get cacheSize => _cache.length;

  Future<_GeminiResponse> _invokeGeminiBeta({
    required String prompt,
    required int maxOutputTokens,
    required String label,
    required Map<String, dynamic> schema,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );
    debugPrint('📤 Sending request to Gemini ($label)...');

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        'temperature': 0.1, // Lower temperature for more consistent, accurate results
        'topP': 0.95,
        'topK': 40,
        'responseMimeType': 'application/json',
        'responseSchema': schema,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
      ],
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    debugPrint('📥 Received response from Gemini ($label) with status ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('❌ Gemini API HTTP error: ${response.statusCode} ${response.reasonPhrase}');
      debugPrint('Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      throw http.ClientException('API returned ${response.statusCode}: ${response.reasonPhrase}');
    }

    final rawBody = response.body;
    final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      debugPrint('⚠️  No candidates returned from Gemini ($label)');
      return _GeminiResponse(rawBody: rawBody);
    }

    String? text;
    for (final candidate in candidates) {
      final content = candidate is Map<String, dynamic> ? candidate['content'] : null;
      final parts = content is Map<String, dynamic> ? content['parts'] : null;

      if (parts is List) {
        final buffer = StringBuffer();
        for (final part in parts) {
          if (part is Map<String, dynamic>) {
            final partText = part['text'];
            if (partText is String && partText.trim().isNotEmpty) {
              buffer.write(partText);
            }
          }
        }
        if (buffer.isNotEmpty) {
          text = buffer.toString().trim();
          break;
        }
      }
    }

    return _GeminiResponse(rawBody: rawBody, text: text);
  }

  /// Fetch word meaning from Gemini API with caching and retry logic
  Future<Word?> getWordMeaning(String word) async {
    final normalizedWord = word.trim();
    if (normalizedWord.isEmpty) {
      debugPrint('⚠️  Empty word provided');
      return null;
    }

    // Check cache first
    if (_cache.containsKey(normalizedWord)) {
      debugPrint('💾 Cache hit for: "$normalizedWord"');
      return _cache[normalizedWord];
    }

    // Check if there's already a pending request for this word
    if (_pendingRequests.containsKey(normalizedWord)) {
      debugPrint('⏳ Awaiting existing request for: "$normalizedWord"');
      return await _pendingRequests[normalizedWord];
    }

    // Create new request
    final requestFuture = _fetchWordMeaning(normalizedWord);
    _pendingRequests[normalizedWord] = requestFuture;

    try {
      final result = await requestFuture;
      if (result != null) {
        _cache[normalizedWord] = result;
        debugPrint('✅ Cached result for: "$normalizedWord" (cache size: ${_cache.length})');
      }
      return result;
    } finally {
      _pendingRequests.remove(normalizedWord);
    }
  }

  /// Internal method to fetch word meaning with retry logic
  Future<Word?> _fetchWordMeaning(String word) async {
    int attempt = 0;
    Duration delay = _initialRetryDelay;

    while (attempt < _maxRetries) {
      try {
        attempt++;
        debugPrint('🚀 Attempt $attempt/$_maxRetries for: "$word"');

        final result = await _makeApiRequest(word).timeout(
          _requestTimeout,
          onTimeout: () {
            throw TimeoutException('API request timed out after $_requestTimeout');
          },
        );

        if (result != null) {
          return result;
        }

        // If result is null but no exception, don't retry
        debugPrint('⚠️  No result returned for: "$word"');
        return null;
      } on TimeoutException catch (e) {
        debugPrint('⏱️  Timeout on attempt $attempt: $e');
        if (attempt >= _maxRetries) {
          debugPrint('❌ Max retries reached due to timeout');
          return null;
        }
      } on http.ClientException catch (e) {
        debugPrint('🌐 Network error on attempt $attempt: $e');
        if (attempt >= _maxRetries) {
          debugPrint('❌ Max retries reached due to network error');
          return null;
        }
      } catch (e) {
        debugPrint('❌ Error on attempt $attempt: $e');
        if (attempt >= _maxRetries) {
          debugPrint('❌ Max retries reached');
          return null;
        }
      }

      // Wait before retrying (exponential backoff)
      if (attempt < _maxRetries) {
        debugPrint('⏳ Waiting ${delay.inMilliseconds}ms before retry...');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }

    return null;
  }

  /// Make the actual API request using structured JSON mode
  Future<Word?> _makeApiRequest(String word) async {
    final response = await _invokeGeminiBeta(
      prompt: _improvedPrompt(word),
      maxOutputTokens: 2048,
      label: 'structured-json',
      schema: _improvedSchema(),
    );

    if (response.text != null && response.text!.isNotEmpty) {
      debugPrint('✅ Response received (${response.text!.length} chars)');
      return _parseApiResponse(response.text!, word);
    }

    debugPrint('⚠️  Empty response from API');
    return null;
  }

  // Parse API response and create a Word object
  Word? _parseApiResponse(String response, String originalWord) {
    try {
      // Attempt to extract JSON from response
      int startIndex = response.indexOf('{');
      int endIndex = response.lastIndexOf('}') + 1;
      
      if (startIndex != -1 && endIndex != 0) {
        String jsonString = response.substring(startIndex, endIndex);
        Map<String, dynamic> jsonData = json.decode(jsonString);

        return Word(
          word: originalWord,
          meaning: _stringify(jsonData['meaning_ar']) ?? _stringify(jsonData['meaning']) ?? 'Meaning not available',
          meaningEn: _stringify(jsonData['meaning_en']),
          meaningUr: _stringify(jsonData['meaning_ur']),
          rootWord: _stringify(jsonData['root_word']),
          history: _stringify(jsonData['history']),
          examples: _stringify(jsonData['examples']),
          relatedWords: _stringify(jsonData['related_words']),
        );
      } else {
        // If JSON parsing fails, return a basic word with the full response as meaning
        return Word(
          word: originalWord,
          meaning: response,
        );
      }
    } catch (e) {
      debugPrint('Failed to parse Gemini response: $e');
      return Word(
        word: originalWord,
        meaning: response,
      );
    }
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return value.map((item) => _stringify(item) ?? '').where((item) => item.isNotEmpty).join('; ');
    }
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${_stringify(entry.value) ?? ''}'.trim())
          .where((entry) => entry.trim().isNotEmpty)
          .join('\n');
    }
    return value.toString();
  }

  /// Improved prompt optimized for classical Arabic dictionary entries
  String _improvedPrompt(String word) {
    return '''أنت قاموس عربي متخصص في اللغة العربية الفصحى والكلمات القرآنية.

المهمة: قدم تحليلاً شاملاً ومفصلاً للكلمة العربية "$word"

التعليمات:
1. معنى الكلمة بالعربية (meaning_ar): قدم شرحاً وافياً ودقيقاً بالعربية الفصحى، مع ذكر المعاني المختلفة إن وجدت
2. المعنى بالإنجليزية (meaning_en): ترجمة دقيقة ومفصلة باللغة الإنجليزية
3. المعنى بالأردية (meaning_ur): ترجمة بخط النستعليق الأردوي إن أمكن
4. الجذر اللغوي (root_word): حدد الجذر الثلاثي أو الرباعي للكلمة
5. أصل الكلمة وتاريخها (history): معلومات عن الأصل اللغوي والتطور التاريخي للكلمة
6. أمثلة (examples): أمثلة من القرآن الكريم أو الحديث الشريف أو الشعر العربي
7. كلمات مرتبطة (related_words): المشتقات والمرادفات والكلمات ذات الصلة

ملاحظة: إذا كانت الكلمة قرآنية، فأعط اهتماماً خاصاً للمعنى في السياق القرآني.
''';
  }

  /// Improved JSON schema with better structure and validation
  Map<String, dynamic> _improvedSchema() {
    return {
      'type': 'OBJECT',
      'properties': {
        'word': {
          'type': 'STRING',
          'description': 'The Arabic word being defined',
        },
        'meaning_ar': {
          'type': 'STRING',
          'description': 'Comprehensive meaning in classical Arabic',
        },
        'meaning_en': {
          'type': 'STRING',
          'description': 'Detailed English translation',
        },
        'meaning_ur': {
          'type': 'STRING',
          'description': 'Urdu translation in Nastaliq script',
          'nullable': true,
        },
        'root_word': {
          'type': 'STRING',
          'description': 'The trilateral or quadrilateral root',
          'nullable': true,
        },
        'history': {
          'type': 'STRING',
          'description': 'Etymology and historical development',
          'nullable': true,
        },
        'examples': {
          'type': 'STRING',
          'description': 'Examples from Quran, Hadith, or classical poetry',
          'nullable': true,
        },
        'related_words': {
          'type': 'STRING',
          'description': 'Derivatives, synonyms, and related terms',
          'nullable': true,
        },
      },
      'required': ['word', 'meaning_ar', 'meaning_en'],
    };
  }
}

class _GeminiResponse {
  final String rawBody;
  final String? text;

  _GeminiResponse({required this.rawBody, this.text});
}