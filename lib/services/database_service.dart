import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'haramcopy4.db';
  static bool _ftsAvailable = true;
  static final Random _random = Random();

  static const int _kDatabaseVersion = 2; // Increment this to trigger update

  // Initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    // Get the database path
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, _dbName);

    // Check if the database exists in the app directory
    bool exists = await databaseExists(path);

    if (!exists) {
      // First install: Copy the pre-populated database from assets
      try {
        await _copyDatabaseFromAssets(path);
        // Save current version
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('db_version', _kDatabaseVersion);
      } catch (e) {
        debugPrint('Failed to copy database from assets: $e');
        rethrow;
      }
    } else {
      // Check for updates
      await _checkDatabaseUpdate(path);
    }

    try {
      final db = await openDatabase(
        path,
        version: _kDatabaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onOpen: (database) async {
          await _ensureMetaTable(database);
          await _ensureSearchIndexes(database);
          await _ensureFtsIndex(database);
          await _ensureUserTables(database);
        },
      );

      return db;
    } on DatabaseException catch (e) {
      debugPrint('Database open failed: $e');
      throw Exception('Failed to open database: $e');
    }
  }

  // Check if database needs update and handle safe migration
  Future<void> _checkDatabaseUpdate(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt('db_version') ?? 0;

      if (currentVersion < _kDatabaseVersion) {
        debugPrint(
          '🔄 Updating database from v$currentVersion to v$_kDatabaseVersion...',
        );

        // 1. Open existing DB to backup user data
        final db = await openDatabase(path);
        await db.execute('PRAGMA foreign_keys = ON');
        final userData = await _backupUserData(db);
        await db.close();

        // 2. Overwrite database file
        await _copyDatabaseFromAssets(path);

        // 3. Re-open and restore user data
        final newDb = await openDatabase(path);
        await newDb.execute('PRAGMA foreign_keys = ON');
        // Ensure tables exist in new DB (just in case)
        await _ensureUserTables(newDb);
        await _restoreUserData(newDb, userData);

        // 4. Update version
        await prefs.setInt('db_version', _kDatabaseVersion);
        debugPrint('✅ Database updated successfully!');
      }
    } catch (e) {
      debugPrint('❌ Database update failed: $e');
      // Store update failure for UI to show
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('db_update_failed', true);
        await prefs.setString('db_update_error', e.toString());
      } catch (_) {}
      // Fallback: Do nothing, keep using old DB to avoid data loss
    }
  }

  // Backup user data (favorites, history, collections)
  Future<Map<String, List<Map<String, dynamic>>>> _backupUserData(
    Database db,
  ) async {
    final data = <String, List<Map<String, dynamic>>>{};

    try {
      // Check if tables exist before querying
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      if (tableNames.contains('search_history')) {
        data['search_history'] = await db.query('search_history');
      }
      if (tableNames.contains('favorites')) {
        data['favorites'] = await db.query('favorites');
      }
      if (tableNames.contains('collections')) {
        data['collections'] = await db.query('collections');
      }
      if (tableNames.contains('collection_items')) {
        data['collection_items'] = await db.query('collection_items');
      }
      if (tableNames.contains('app_meta')) {
        // Backup settings only, not FTS status or WOD
        data['app_meta'] = await db.query(
          'app_meta',
          where:
              "key NOT IN ('fts_index_built', 'wod_date', 'wod_word', 'wod_source')",
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error backing up user data: $e');
    }

    return data;
  }

  // Restore user data
  Future<void> _restoreUserData(
    Database db,
    Map<String, List<Map<String, dynamic>>> data,
  ) async {
    await db.transaction((txn) async {
      // Restore Search History
      if (data.containsKey('search_history')) {
        for (final row in data['search_history']!) {
          await txn.insert('search_history', row);
        }
      }

      // Restore Favorites
      if (data.containsKey('favorites')) {
        for (final row in data['favorites']!) {
          await txn.insert(
            'favorites',
            row,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      // Restore Collections (preserve IDs)
      if (data.containsKey('collections')) {
        for (final row in data['collections']!) {
          await txn.insert(
            'collections',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Restore Collection Items
      if (data.containsKey('collection_items')) {
        for (final row in data['collection_items']!) {
          await txn.insert(
            'collection_items',
            row,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      // Restore Settings
      if (data.containsKey('app_meta')) {
        for (final row in data['app_meta']!) {
          await txn.insert(
            'app_meta',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
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

  // Create indexes to speed up lookups used by search
  Future<void> _ensureSearchIndexes(Database db) async {
    // Standard dictionaries
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_muashiroh_word ON ${DictionarySource.muashiroh.tableName}(word)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wasith_word ON ${DictionarySource.wasith.tableName}(word)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_muhith_word ON ${DictionarySource.muhith.tableName}(word)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_shihah_word ON ${DictionarySource.shihah.tableName}(word)',
    );

    // Ghoni
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ghoni_arabic_word ON ${DictionarySource.ghoni.tableName}(arabic_word)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ghoni_arabic_noharokah ON ${DictionarySource.ghoni.tableName}(arabic_noharokah)',
    );

    // Lisan ul Arab
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lisan_noharokah ON ${DictionarySource.lisanularab.tableName}(arabic_noharokah)',
    );

    // Ghoribul Quran
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ghorib_noharokah ON ${DictionarySource.ghoribulquran.tableName}(arabic_noharokah)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ghorib_ayah ON ${DictionarySource.ghoribulquran.tableName}(ayah)',
    );
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

  // User tables for history and favorites
  Future<void> _ensureUserTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        meaning TEXT,
        source TEXT,
        timestamp INTEGER NOT NULL,
        UNIQUE(word, source)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        color INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS collection_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        meaning TEXT,
        source TEXT,
        added_at INTEGER NOT NULL,
        FOREIGN KEY(collection_id) REFERENCES collections(id) ON DELETE CASCADE,
        UNIQUE(collection_id, word, source)
      )
    ''');
  }

  // Build FTS5 index over dictionary content (one-time)
  Future<void> _ensureFtsIndex(Database db) async {
    if (!_ftsAvailable) return;
    try {
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='entries_fts' LIMIT 1",
      );
      final built = await db.rawQuery(
        "SELECT value FROM app_meta WHERE key='fts_index_built' LIMIT 1",
      );
      final isBuilt = built.isNotEmpty && built.first['value'] == '1';

      if (tableExists.isNotEmpty) {
        if (isBuilt) return;
        final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM entries_fts'),
        );
        if ((count ?? 0) > 0) {
          await db.insert('app_meta', {
            'key': 'fts_index_built',
            'value': '1',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          return;
        }
      } else if (isBuilt) {
        await db.delete(
          'app_meta',
          where: 'key = ?',
          whereArgs: ['fts_index_built'],
        );
      }

      await db.execute(
        "CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(headword_raw, headword_norm, meaning, source, tokenize='unicode61 remove_diacritics 2')",
      );

      await db.transaction((txn) async {
        await txn.delete('entries_fts');

        Future<void> insertRows(
          String headSql,
          List<List<Object?>> rows,
        ) async {
          final batch = txn.batch();
          for (final r in rows) {
            batch.rawInsert(
              'INSERT INTO entries_fts (headword_raw, headword_norm, meaning, source) VALUES (?,?,?,?)',
              r,
            );
          }
          await batch.commit(noResult: true);
        }

        // Populate from each dictionary
        for (final s in DictionarySource.searchableDictionaries) {
          final t = s.tableName;
          List<Map<String, Object?>> maps = [];
          switch (s) {
            case DictionarySource.ghoni:
              maps = await txn.rawQuery(
                'SELECT arabic_word AS hw, arabic_noharokah AS hwn, arabic_meanings AS m FROM $t',
              );
              break;
            case DictionarySource.lisanularab:
              maps = await txn.rawQuery(
                'SELECT arabic_noharokah AS hw, arabic_noharokah AS hwn, arabic_meanings AS m FROM $t',
              );
              break;
            case DictionarySource.ghoribulquran:
              maps = await txn.rawQuery(
                'SELECT arabic_noharokah AS hw, arabic_noharokah AS hwn, meaning AS m FROM $t',
              );
              break;
            default:
              maps = await txn.rawQuery(
                'SELECT word AS hw, word AS hwn, meaning AS m FROM $t',
              );
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

        await txn.insert('app_meta', {
          'key': 'fts_index_built',
          'value': '1',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<Map<String, dynamic>?> _getRandomRow(
    Database db,
    String tableName,
  ) async {
    final maxRowId = Sqflite.firstIntValue(
      await db.rawQuery('SELECT MAX(rowid) FROM $tableName'),
    );
    if (maxRowId == null || maxRowId <= 0) return null;
    final seed = _random.nextInt(maxRowId) + 1;
    final maps = await db.rawQuery(
      'SELECT rowid AS _rid, * FROM $tableName WHERE rowid >= ? LIMIT 1',
      [seed],
    );
    if (maps.isNotEmpty) return maps.first;
    final fallback = await db.rawQuery(
      'SELECT rowid AS _rid, * FROM $tableName LIMIT 1',
    );
    return fallback.isNotEmpty ? fallback.first : null;
  }

  Future<List<Map<String, dynamic>>> _getRandomRows(
    Database db,
    String tableName,
    int limit,
  ) async {
    if (limit <= 0) return [];
    final maxRowId = Sqflite.firstIntValue(
      await db.rawQuery('SELECT MAX(rowid) FROM $tableName'),
    );
    if (maxRowId == null || maxRowId <= 0) return [];
    final used = <int>{};
    final results = <Map<String, dynamic>>[];
    int attempts = 0;
    final maxAttempts = limit * 6;

    while (results.length < limit && attempts < maxAttempts) {
      attempts++;
      final seed = _random.nextInt(maxRowId) + 1;
      final maps = await db.rawQuery(
        'SELECT rowid AS _rid, * FROM $tableName WHERE rowid >= ? LIMIT 1',
        [seed],
      );
      if (maps.isEmpty) continue;
      final row = maps.first;
      final rid = row['_rid'];
      if (rid is int && used.contains(rid)) continue;
      if (rid is int) used.add(rid);
      results.add(row);
    }

    if (results.isEmpty) {
      return await db.rawQuery('SELECT * FROM $tableName LIMIT ?', [limit]);
    }
    return results;
  }

  // Return all dictionary entries for a headword from all sources (aggregated view)
  Future<List<Word>> getAllEntries(
    String inputWord, {
    DictionarySource? source,
  }) async {
    final db = await database;
    final normalized = _normalizeArabic(inputWord);
    final List<Word> results = [];
    final Set<String> seen = {};

    final Iterable<DictionarySource> sources =
        (source != null && source != DictionarySource.all)
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
          maps = await db.rawQuery('SELECT * FROM $table WHERE word = ?', [
            inputWord,
          ]);
      }

      for (final map in maps) {
        final w = Word.fromMap(map, source: s);
        final entryId =
            map['id'] ?? map['arabic_id'] ?? map['ID'] ?? map['_rid'];
        final key = entryId != null
            ? '${s.tableName}|$entryId'
            : '${s.tableName}|${w.word}|${w.meaning}';
        if (seen.add(key)) {
          results.add(w);
        }
      }
    }

    return results;
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
  Future<Word?> _searchInDictionary(
    String word,
    DictionarySource source,
  ) async {
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
  Future<List<Word>> searchWords(
    String query, {
    DictionarySource? source,
    int limit = 10,
  }) async {
    final db = await database;
    final qn = _normalizeArabic(query);
    List<Word> allResults = [];

    if (source != null && source != DictionarySource.all) {
      return await _searchWordsInDictionary(query, source, limit);
    }

    // Optimized UNION ALL query for global search
    try {
      final queries = <String>[];
      final args = <Object>[];

      for (final s in DictionarySource.searchableDictionaries) {
        final t = s.tableName;

        switch (s) {
          case DictionarySource.ghoni:
            queries.add('''
              SELECT arabic_word AS w, arabic_meanings AS m, '${s.tableName}' as s 
              FROM $t 
              WHERE arabic_word LIKE ? OR arabic_noharokah LIKE ?
            ''');
            args.addAll(['$query%', '$qn%']);
            break;
          case DictionarySource.lisanularab:
            queries.add('''
              SELECT arabic_noharokah AS w, arabic_meanings AS m, '${s.tableName}' as s 
              FROM $t 
              WHERE arabic_noharokah LIKE ?
            ''');
            args.add('$qn%');
            break;
          case DictionarySource.ghoribulquran:
            queries.add('''
              SELECT arabic_noharokah AS w, meaning AS m, '${s.tableName}' as s 
              FROM $t 
              WHERE arabic_noharokah LIKE ? OR ayah LIKE ?
            ''');
            args.addAll(['$qn%', '$query%']);
            break;
          default:
            queries.add('''
              SELECT word AS w, meaning AS m, '${s.tableName}' as s 
              FROM $t 
              WHERE word LIKE ?
            ''');
            args.add('$query%');
        }
      }

      final fullQuery = '${queries.join(' UNION ALL ')} LIMIT $limit';
      final maps = await db.rawQuery(fullQuery, args);

      for (final map in maps) {
        final srcName = map['s'] as String;
        final src = DictionarySource.values.firstWhere(
          (s) => s.tableName == srcName,
          orElse: () => DictionarySource.muashiroh,
        );

        allResults.add(
          Word(
            word: map['w'] as String,
            meaning: map['m'] as String,
            source: src,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in global search: $e');
      // Fallback to iterative if something goes wrong
      for (var dict in DictionarySource.searchableDictionaries) {
        final results = await _searchWordsInDictionary(
          query,
          dict,
          limit ~/ DictionarySource.searchableDictionaries.length + 1,
        );
        allResults.addAll(results);
      }
    }

    // Augment with FTS if searching across all sources
    if (source == null || source == DictionarySource.all) {
      final fts = await _searchWordsFts(query, limit);
      final seen = <String>{
        for (final w in allResults) '${w.source?.tableName}|${w.word}',
      };
      for (final w in fts) {
        final key = '${w.source?.tableName}|${w.word}';
        if (!seen.contains(key)) {
          allResults.add(w);
          seen.add(key);
        }
      }
    }

    // Sort by relevance using normalized equality and prefix boosts
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
  Future<List<Word>> _searchWordsInDictionary(
    String query,
    DictionarySource source,
    int limit,
  ) async {
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
      final match =
          'headword_norm:"$qn*" OR headword_raw:"$query*" OR meaning:"$query*"';
      final rows = await db.rawQuery(
        'SELECT headword_raw, headword_norm, meaning, source, bm25(entries_fts) AS rank FROM entries_fts WHERE entries_fts MATCH ? ORDER BY rank LIMIT ?',
        [match, limit],
      );
      final out = <Word>[];
      for (final r in rows) {
        final srcName = (r['source'] ?? '').toString();
        DictionarySource? src;
        for (final s in DictionarySource.values) {
          if (s.tableName == srcName) {
            src = s;
            break;
          }
        }
        out.add(
          Word(
            word: (r['headword_raw'] ?? '').toString(),
            meaning: (r['meaning'] ?? '').toString(),
            source: src,
          ),
        );
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

  // --- User Data Methods ---

  Future<List<Word>> getSearchHistory({int limit = 10, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'search_history',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    List<Word> historyWords = [];
    for (var m in maps) {
      String query = m['query'] as String;
      Word? wordDetails = await getWord(query);
      if (wordDetails != null) {
        historyWords.add(wordDetails);
      } else {
        historyWords.add(
          Word(word: query, meaning: 'Tap to search', source: null),
        );
      }
    }
    return historyWords;
  }

  // Clear all search history
  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  Future<void> addSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final db = await database;
    // Remove existing entry to move it to top
    await db.delete('search_history', where: 'query = ?', whereArgs: [query]);
    await db.insert('search_history', {
      'query': query,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Word>> getFavorites() async {
    final db = await database;
    final maps = await db.query('favorites', orderBy: 'timestamp DESC');

    return maps.map((m) {
      final srcName = m['source'] as String?;
      DictionarySource? src;
      if (srcName != null) {
        try {
          src = DictionarySource.values.firstWhere(
            (s) => s.tableName == srcName || s.name == srcName,
            orElse: () => DictionarySource.all,
          );
          if (src == DictionarySource.all) src = null;
        } catch (_) {}
      }

      return Word(
        word: m['word'] as String,
        meaning: m['meaning'] as String? ?? '',
        source: src,
      );
    }).toList();
  }

  Future<void> toggleFavorite(Word word) async {
    final db = await database;
    final isFav = await isFavorite(word);
    final srcName = word.source?.tableName ?? 'all';

    if (isFav) {
      await db.delete(
        'favorites',
        where: 'word = ? AND source = ?',
        whereArgs: [word.word, srcName],
      );
    } else {
      await db.insert('favorites', {
        'word': word.word,
        'meaning': word.meaning,
        'source': srcName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<bool> isFavorite(Word word) async {
    final db = await database;
    final srcName = word.source?.tableName ?? 'all';
    final maps = await db.query(
      'favorites',
      where: 'word = ? AND source = ?',
      whereArgs: [word.word, srcName],
    );
    return maps.isNotEmpty;
  }

  // --- Word of the Day ---

  Future<Word?> getWordOfTheDay() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Check if we already have a WOD for today
    final metaMaps = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['wod_date'],
    );

    if (metaMaps.isNotEmpty && metaMaps.first['value'] == today) {
      // Fetch the stored word
      final wordMap = await db.query('app_meta', where: "key = 'wod_word'");
      final sourceMap = await db.query('app_meta', where: "key = 'wod_source'");

      if (wordMap.isNotEmpty && sourceMap.isNotEmpty) {
        final wordText = wordMap.first['value'] as String;
        final sourceName = sourceMap.first['value'] as String;

        // Find the source enum
        DictionarySource? source;
        try {
          source = DictionarySource.values.firstWhere(
            (s) => s.tableName == sourceName,
            orElse: () => DictionarySource.muashiroh,
          );
        } catch (_) {}

        // Fetch full word details
        return await getWord(wordText, source: source);
      }
    }

    // Generate new WOD
    try {
      // Randomly select a source
      final sources = DictionarySource.searchableDictionaries;
      final randomSource =
          sources[DateTime.now().millisecondsSinceEpoch % sources.length];
      final tableName = randomSource.tableName;

      final row = await _getRandomRow(db, tableName);

      if (row != null) {
        final word = Word.fromMap(row, source: randomSource);

        // Store in meta
        await db.insert('app_meta', {
          'key': 'wod_date',
          'value': today,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await db.insert('app_meta', {
          'key': 'wod_word',
          'value': word.word,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await db.insert('app_meta', {
          'key': 'wod_source',
          'value': randomSource.tableName,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        return word;
      }
    } catch (e) {
      debugPrint('Error generating WOD: $e');
    }

    return null;
  }
  // --- Discover Features ---

  Future<List<Word>> getRandomWords({
    DictionarySource? source,
    int limit = 5,
  }) async {
    final db = await database;
    final tableName = source?.tableName ?? DictionarySource.muashiroh.tableName;

    try {
      final maps = await _getRandomRows(db, tableName, limit);

      return maps
          .map(
            (map) =>
                Word.fromMap(map, source: source ?? DictionarySource.muashiroh),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching random words: $e');
      return [];
    }
  }

  // --- Settings Persistence ---

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('app_meta', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Collections ---

  Future<int> createCollection(String name, {int? color}) async {
    final db = await database;
    return await db.insert('collections', {
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'color': color,
    });
  }

  Future<List<Map<String, dynamic>>> getCollections() async {
    final db = await database;
    final res = await db.query('collections', orderBy: 'created_at DESC');

    // Get count for each collection
    final List<Map<String, dynamic>> collections = [];
    for (var c in res) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM collection_items WHERE collection_id = ?',
          [c['id']],
        ),
      );
      final map = Map<String, dynamic>.from(c);
      map['count'] = count ?? 0;
      collections.add(map);
    }
    return collections;
  }

  Future<void> deleteCollection(int id) async {
    final db = await database;
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addToCollection(int collectionId, Word word) async {
    final db = await database;
    final srcName = word.source?.tableName ?? 'all';

    await db.insert('collection_items', {
      'collection_id': collectionId,
      'word': word.word,
      'meaning': word.meaning,
      'source': srcName,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeFromCollection(int collectionId, Word word) async {
    final db = await database;
    final srcName = word.source?.tableName ?? 'all';

    await db.delete(
      'collection_items',
      where: 'collection_id = ? AND word = ? AND source = ?',
      whereArgs: [collectionId, word.word, srcName],
    );
  }

  Future<List<Word>> getCollectionWords(int collectionId) async {
    final db = await database;
    final maps = await db.query(
      'collection_items',
      where: 'collection_id = ?',
      orderBy: 'added_at DESC',
      whereArgs: [collectionId],
    );

    return maps.map((m) {
      final srcName = m['source'] as String?;
      DictionarySource? src;
      if (srcName != null) {
        try {
          src = DictionarySource.values.firstWhere(
            (s) => s.tableName == srcName || s.name == srcName,
            orElse: () => DictionarySource.all,
          );
          if (src == DictionarySource.all) src = null;
        } catch (_) {}
      }

      return Word(
        word: m['word'] as String,
        meaning: m['meaning'] as String? ?? '',
        source: src,
      );
    }).toList();
  }
}
