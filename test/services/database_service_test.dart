import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arabic_dictionary_app/services/database_service.dart';

void main() {
  late DatabaseService databaseService;

  setUpAll(() async {
    // Initialize Flutter bindings for asset access
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    // Initialize sqflite for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    databaseService = DatabaseService();
  });

  test('Database service should initialize properly', () async {
    final db = await databaseService.database;
    expect(db, isNotNull);
  });

  test('Word search returns results from dictionaries', () async {
    // Search for a common Arabic word that should exist in dictionaries
    final results = await databaseService.searchWords('كتاب');
    
    // Dictionaries should contain this word
    expect(results, isNotEmpty);
  });

  test('Dictionary-specific search works', () async {
    // Test searching across all dictionaries
    final word = await databaseService.getWord('كتاب');
    
    // Should find word in at least one dictionary
    expect(word, isNotNull);
    if (word != null) {
      expect(word.word, isNotEmpty);
      expect(word.meaning, isNotEmpty);
    }
  });

  tearDown(() async {
    await databaseService.close();
  });
}