import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arabic_dictionary_app/services/database_service.dart';
import 'package:arabic_dictionary_app/services/search_service.dart';

void main() {
  late DatabaseService databaseService;
  late SearchService searchService;

  setUpAll(() async {
    // Initialize Flutter bindings for asset access
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    // Initialize sqflite for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    databaseService = DatabaseService();
    searchService = SearchService(databaseService: databaseService);
  });

  test('Search service returns word from dictionaries', () async {
    // Search for a common word that should exist in dictionaries
    final result = await searchService.searchWord('كتاب');

    // Should find word in at least one dictionary
    expect(result, isNotNull);
    if (result != null) {
      expect(result.word, isNotEmpty);
      expect(result.meaning, isNotEmpty);
    }
  });

  test('Search suggestions work', () async {
    // Get search suggestions for a common Arabic prefix
    final suggestions = await searchService.getSearchSuggestions('كت');

    // Should return suggestions from dictionaries
    expect(suggestions, isNotEmpty);
    expect(suggestions.every((word) => word.word.isNotEmpty), isTrue);
  });

  tearDown(() async {
    await databaseService.close();
  });
}