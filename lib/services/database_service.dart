import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'haramcopy4.db';
  static bool _ftsAvailable = true;

  // Initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Create indexes to speed up lookups used by search
  Future<void> _ensureSearchIndexes(Database db) async {
    // Standard dictionaries
    await db.execute('CREATE INDEX IF NOT EXISTS idx_muashiroh_word ON mujamul_muashiroh(word)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wasith_word ON mujamul_wasith(word)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_muhith_word ON mujamul_muhith(word)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shihah_word ON mujamul_shihah(word)');

    // Ghoni
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ghoni_arabic_word ON mujamul_ghoni(arabic_word)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ghoni_arabic_noharokah ON mujamul_ghoni(arabic_noharokah)');

    // Lisan ul Arab
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lisan_noharokah ON lisanularab(arabic_noharokah)');

    // Ghoribul Quran
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ghorib_noharokah ON ghoribulquran(arabic_noharokah)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ghorib_ayah ON ghoribulquran(ayah)');
  }

  // Meta key-value table
  Future<void> _ensureMetaTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // Build FTS5 index over dictionary content (one-time)
  Future<void> _ensureFtsIndex(Database db) async {
    if (!_ftsAvailable) return;
    try {
      final built = await db.rawQuery(
        "SELECT value FROM app_meta WHERE key='fts_index_built' LIMIT 1",
      );
      if (built.isNotEmpty && built.first['value'] == '1') return;

      await db.execute(
        "CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(headword_raw, headword_norm, meaning, source, tokenize='unicode61 remove_diacritics 2')",
      );

      await db.transaction((txn) async {
        await txn.delete('entries_fts');

        Future<void> insertRows(String headSql, List<List<Object?>> rows) async {
          final batch = txn.batch();
          for (final r in rows) {
            batch.rawInsert('INSERT INTO entries_fts (headword_raw, headword_norm, meaning, source) VALUES (?,?,?,?)', r);
          }
          await batch.commit(noResult: true);
        }

        // Populate from each dictionary
        for (final s in DictionarySource.searchableDictionaries) {
          final t = s.tableName;
          List<Map<String, Object?>> maps = [];
          switch (s) {
            case DictionarySource.ghoni:
              maps = await txn.rawQuery('SELECT arabic_word AS hw, arabic_noharokah AS hwn, arabic_meanings AS m FROM $t');
              break;
            case DictionarySource.lisanularab:
              maps = await txn.rawQuery('SELECT arabic_noharokah AS hw, arabic_noharokah AS hwn, arabic_meanings AS m FROM $t');
              break;
            case DictionarySource.ghoribulquran:
              maps = await txn.rawQuery('SELECT arabic_noharokah AS hw, arabic_noharokah AS hwn, meaning AS m FROM $t');
              break;
            default:
              maps = await txn.rawQuery('SELECT word AS hw, word AS hwn, meaning AS m FROM $t');
          }
          final rows = <List<Object?>>[];
          for (final row in maps) {
            final raw = (row['hw'] ?? '').toString();
            final norm = _normalizeArabic((row['hwn'] ?? raw).toString());
            final meaning = (row['m'] ?? '').toString();
            if (raw.isEmpty && meaning.isEmpty) continue;
            rows.add([raw, norm, meaning, s.tableName]);
            if (rows.length >= 500) {
              await insertRows('entries_fts', rows);
              rows.clear();
            }
          }
          if (rows.isNotEmpty) {
            await insertRows('entries_fts', rows);
          }
        }

        await txn.insert('app_meta', {'key': 'fts_index_built', 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (msg.contains('no such module: fts5')) {
        _ftsAvailable = false;
        debugPrint('FTS index disabled: $e');
        return;
      }
      debugPrint('FTS index build failed: $e');
    } catch (e) {
      debugPrint('FTS index build failed: $e');
    }
  }

  // Normalize Arabic (strip diacritics and unify common variants) for matching
  String _normalizeArabic(String input) {
    final diacritics = RegExp(r'[\u064B-\u065F\u0670]');
    var out = input.replaceAll(diacritics, '');
    out = out.replaceAll('\u0640', ''); // Tatweel
    out = out
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('\u0671', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي');
    return out;
  }

  // Return all dictionary entries for a headword from all sources (aggregated view)
  Future<List<Word>> getAllEntries(String inputWord, {DictionarySource? source}) async {
    final db = await database;
    final normalized = _normalizeArabic(inputWord);
    final List<Word> results = [];
    final Set<String> seen = {};

    final Iterable<DictionarySource> sources = (source != null && source != DictionarySource.all)
        ? [source]
        : DictionarySource.searchableDictionaries;

    for (final s in sources) {
      final table = s.tableName;
      List<Map<String, dynamic>> maps = [];

      switch (s) {
        case DictionarySource.ghoni:
          maps = await db.rawQuery(
            'SELECT * FROM $table WHERE arabic_word = ? OR arabic_noharokah = ?',
            [inputWord, normalized],
          );
          break;
        case DictionarySource.lisanularab:
          maps = await db.rawQuery(
            'SELECT * FROM $table WHERE arabic_noharokah = ?',
            [normalized],
          );
          break;
        case DictionarySource.ghoribulquran:
          maps = await db.rawQuery(
            'SELECT * FROM $table WHERE arabic_noharokah = ?',
            [normalized],
          );
          break;
        default:
          maps = await db.rawQuery(
            'SELECT * FROM $table WHERE word = ?',
            [inputWord],
          );
      }

      for (final map in maps) {
        final w = Word.fromMap(map, source: s);
        final key = '${s.tableName}|${w.word}';
        if (!seen.contains(key)) {
          seen.add(key);
          results.add(w);
        }
      }
    }

    return results;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    // Get the database path
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, _dbName);

    // Check if the database exists in the app directory
    bool exists = await databaseExists(path);

    if (!exists) {
      // Copy the pre-populated database from assets
      try {
        await _copyDatabaseFromAssets(path);
      } catch (e) {
        debugPrint('Failed to copy database from assets: $e');
        rethrow;
      }
    }

    try {
      final db = await openDatabase(
        path,
        version: 1,
        onOpen: (database) async {
          await _ensureMetaTable(database);
          await _ensureSearchIndexes(database);
          await _ensureFtsIndex(database);
        },
      );

      return db;
    } on DatabaseException catch (e) {
      debugPrint('Database open failed: $e');
      throw Exception('Failed to open database: $e');
    }
  }

  // Copy database from assets to app's local directory
  Future<void> _copyDatabaseFromAssets(String path) async {
    try {
      // Get the database from assets
      ByteData data = await rootBundle.load('assets/database/$_dbName');
      List<int> bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('Error copying database from assets: $e');
      throw Exception('Failed to load database from assets');
    }
  }

  // Search across all dictionaries for a word
  Future<Word?> getWord(String word, {DictionarySource? source}) async {
    if (source != null && source != DictionarySource.all) {
      return await _searchInDictionary(word, source);
    }

    // Search all dictionaries
    for (var dict in DictionarySource.searchableDictionaries) {
      final result = await _searchInDictionary(word, dict);
      if (result != null) return result;
    }
    // Fallback: try FTS to find closest headword across sources
    final fts = await _searchWordsFts(word, 1);
    if (fts.isNotEmpty) {
      return fts.first; // Return top-ranked FTS match
    }
    return null;
  }

  // Search in a specific dictionary
  Future<Word?> _searchInDictionary(String word, DictionarySource source) async {
    final db = await database;
    final tableName = source.tableName;
    final normalized = _normalizeArabic(word);

    try {
      List<Map<String, dynamic>> maps = [];

      // Dictionary-specific queries
      switch (source) {
        case DictionarySource.ghoni:
          maps = await db.rawQuery(
            'SELECT * FROM $tableName WHERE arabic_word = ? OR arabic_noharokah = ? LIMIT 1',
            [word, normalized],
          );
          break;
        case DictionarySource.lisanularab:
          maps = await db.rawQuery(
            'SELECT * FROM $tableName WHERE arabic_noharokah = ? LIMIT 1',
            [normalized],
          );
          break;
        case DictionarySource.ghoribulquran:
          maps = await db.rawQuery(
            'SELECT * FROM $tableName WHERE arabic_noharokah LIKE ? OR ayah LIKE ? OR meaning LIKE ? LIMIT 1',
            ['%$normalized%', '%$word%', '%$word%'],
          );
          break;
        default:
          // Standard dictionaries (wasith, muhith, shihah, muashiroh)
          maps = await db.rawQuery(
            'SELECT * FROM $tableName WHERE word = ? OR word LIKE ? LIMIT 1',
            [word, '%$word%'],
          );
      }

      if (maps.isNotEmpty) {
        return Word.fromMap(maps.first, source: source);
      }
    } catch (e) {
      debugPrint('Error searching in $tableName: $e');
    }
    return null;
  }

  // Search for words across all dictionaries (with partial matching for suggestions)
  Future<List<Word>> searchWords(String query, {DictionarySource? source, int limit = 10}) async {
    if (source != null && source != DictionarySource.all) {
      return await _searchWordsInDictionary(query, source, limit);
    }

    // Search all dictionaries and merge results
    List<Word> allResults = [];
    for (var dict in DictionarySource.searchableDictionaries) {
      final results = await _searchWordsInDictionary(query, dict, limit ~/ DictionarySource.searchableDictionaries.length + 1);
      allResults.addAll(results);
    }

    // Augment with FTS if searching across all sources
    if (source == null || source == DictionarySource.all) {
      final fts = await _searchWordsFts(query, limit);
      final seen = <String>{for (final w in allResults) '${w.source?.tableName}|${w.word}'};
      for (final w in fts) {
        final key = '${w.source?.tableName}|${w.word}';
        if (!seen.contains(key)) {
          allResults.add(w);
          seen.add(key);
        }
      }
    }

    // Sort by relevance using normalized equality and prefix boosts
    final qn = _normalizeArabic(query);
    int score(Word w) {
      final wn = _normalizeArabic(w.word);
      int s = 0;
      if (wn != qn) s += 4;
      if (w.word != query) s += 2;
      if (!wn.startsWith(qn)) s += 2;
      if (!w.word.startsWith(query)) s += 1;
      if (!wn.contains(qn)) s += 1;
      return s;
    }
    allResults.sort((a, b) => score(a).compareTo(score(b)));

    return allResults.take(limit).toList();
  }

  // Search in a specific dictionary with suggestions
  Future<List<Word>> _searchWordsInDictionary(String query, DictionarySource source, int limit) async {
    final db = await database;
    final tableName = source.tableName;
    List<Word> results = [];
    final qn = _normalizeArabic(query);

    try {
      List<Map<String, dynamic>> maps = [];

      switch (source) {
        case DictionarySource.ghoni:
          maps = await db.rawQuery(
            'SELECT * FROM $tableName WHERE arabic_word LIKE ? OR arabic_noharokah LIKE ? ORDER BY arabic_word LIMIT ?',
            ['$query%', '$qn%', limit],
          );
          break;
        case DictionarySource.lisanularab:
          maps = await db.rawQuery(
            'SELECT * FROM $tableName WHERE arabic_noharokah LIKE ? LIMIT ?',
            ['$qn%', limit],
          );
          break;
        case DictionarySource.ghoribulquran:
          maps = await db.rawQuery(
            'SELECT * FROM $tableName WHERE arabic_noharokah LIKE ? OR ayah LIKE ? LIMIT ?',
            ['$qn%', '$query%', limit],
          );
          break;
        default:
          // Standard dictionaries
          maps = await db.rawQuery(
            'SELECT * FROM $tableName WHERE word LIKE ? ORDER BY word LIMIT ?',
            ['$query%', limit],
          );
      }

      results = maps.map((map) => Word.fromMap(map, source: source)).toList();
    } catch (e) {
      debugPrint('Error searching in $tableName: $e');
    }

    return results;
  }

  // FTS-backed search across all sources
  Future<List<Word>> _searchWordsFts(String query, int limit) async {
    if (!_ftsAvailable) return [];
    final db = await database;
    final qn = _normalizeArabic(query);
    try {
      // Ensure FTS structures exist before querying
      await _ensureMetaTable(db);
      await _ensureFtsIndex(db);
      if (!_ftsAvailable) return [];
      // Prefer headword prefix matches, then meaning
      final match = 'headword_norm:"$qn*" OR headword_raw:"$query*" OR meaning:"$query*"';
      final rows = await db.rawQuery(
        'SELECT headword_raw, headword_norm, meaning, source, bm25(entries_fts) AS rank FROM entries_fts WHERE entries_fts MATCH ? ORDER BY rank LIMIT ?',
        [match, limit],
      );
      final out = <Word>[];
      for (final r in rows) {
        final srcName = (r['source'] ?? '').toString();
        DictionarySource? src;
        for (final s in DictionarySource.values) {
          if (s.tableName == srcName) { src = s; break; }
        }
        out.add(Word(
          word: (r['headword_raw'] ?? '').toString(),
          meaning: (r['meaning'] ?? '').toString(),
          source: src,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('FTS search failed: $e');
      return [];
    }
  }

  // Note: Dictionary tables are read-only. Words from Gemini API are not persisted
  // to avoid modifying the reference dictionaries.

  // Close the database
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // Fetch full Quran verse text and surah name for context
  Future<Map<String, String>?> getQuranVerse(int surah, int ayah) async {
    final db = await database;
    try {
      final maps = await db.rawQuery(
        'SELECT arab, nama_surat FROM quran WHERE surat = ? AND ayat = ? LIMIT 1',
        [surah, ayah],
      );
      if (maps.isNotEmpty) {
        final row = maps.first;
        return {
          'arab': row['arab']?.toString() ?? '',
          'nama_surat': row['nama_surat']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint('Error fetching Quran verse ($surah:$ayah): $e');
    }
    return null;
  }
}