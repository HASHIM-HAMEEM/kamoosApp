import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';
import '../utils/ranking.dart' as ranking;
import '../utils/text_clean.dart' as text_clean;
import '../utils/wod_seed.dart' as wod_seed;

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
      if (tableNames.contains('ai_cache')) {
        data['ai_cache'] = await db.query('ai_cache');
      }
      if (tableNames.contains('app_meta')) {
        // Backup settings only, not FTS status or WOD
        data['app_meta'] = await db.query(
          'app_meta',
          where:
              "key NOT IN ('fts_index_built', 'fts_schema_version', 'wod_date', 'wod_word', 'wod_source')",
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

      // Restore AI cache (best-effort; safe to drop if the table is gone)
      if (data.containsKey('ai_cache')) {
        for (final row in data['ai_cache']!) {
          await txn.insert(
            'ai_cache',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
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
    // Cache for Gemini AI lookups, keyed by trimmed headword. Used when the
    // local lexicon has no entry; persisting prevents us from hitting the
    // API again for the same word across app launches.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_cache (
        word TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // Build FTS5 index over dictionary content (one-time).
  //
  // Columns:
  //  - headword_raw:  original headword with diacritics, for exact hits
  //  - headword_norm: diacritic-stripped/variant-unified headword, for fuzzy
  //  - root_norm:     trilateral/quadrilateral root, normalized. Enables
  //                   "type the root, get the family" lookups (typing كتب
  //                   should surface كتاب/مكتبة/كاتب/مكتوب).
  //  - meaning:       full meaning text, used for content search (not for
  //                   the prefix suggestion list).
  //  - source:        dictionary table name, used as a filter.
  //
  // The schema version is tracked in app_meta so changing the schema bumps
  // `_kFtsSchemaVersion` and rebuilds the index on next launch.
  static const int _kFtsSchemaVersion = 3;

  Future<void> _ensureFtsIndex(Database db) async {
    if (!_ftsAvailable) return;
    try {
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='entries_fts' LIMIT 1",
      );
      final builtRow = await db.rawQuery(
        "SELECT value FROM app_meta WHERE key='fts_schema_version' LIMIT 1",
      );
      final currentVersion = builtRow.isNotEmpty
          ? int.tryParse(builtRow.first['value']?.toString() ?? '') ?? 0
          : 0;
      final schemaCurrent =
          tableExists.isNotEmpty && currentVersion == _kFtsSchemaVersion;

      if (schemaCurrent) {
        final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM entries_fts'),
        );
        if ((count ?? 0) > 0) return;
      }

      // Schema changed or empty: drop and rebuild.
      if (tableExists.isNotEmpty) {
        await db.execute('DROP TABLE IF EXISTS entries_fts');
      }

      await db.execute(
        "CREATE VIRTUAL TABLE entries_fts USING fts5("
        "headword_raw, headword_norm, root_norm, meaning, source, "
        "tokenize='unicode61 remove_diacritics 2')",
      );

      await db.transaction((txn) async {
        await txn.delete('entries_fts');

        Future<void> insertRows(List<List<Object?>> rows) async {
          final batch = txn.batch();
          for (final r in rows) {
            batch.rawInsert(
              'INSERT INTO entries_fts (headword_raw, headword_norm, root_norm, meaning, source) VALUES (?,?,?,?,?)',
              r,
            );
          }
          await batch.commit(noResult: true);
        }

        // Populate from each dictionary.
        for (final s in DictionarySource.searchableDictionaries) {
          final t = s.tableName;
          List<Map<String, Object?>> maps = [];
          switch (s) {
            case DictionarySource.ghoni:
              maps = await txn.rawQuery(
                'SELECT arabic_word AS hw, arabic_noharokah AS hwn, arabic_root AS root, arabic_meanings AS m FROM $t',
              );
              break;
            case DictionarySource.lisanularab:
              maps = await txn.rawQuery(
                'SELECT arabic_noharokah AS hw, arabic_noharokah AS hwn, arabic_root AS root, arabic_meanings AS m FROM $t',
              );
              break;
            case DictionarySource.ghoribulquran:
              maps = await txn.rawQuery(
                'SELECT arabic_noharokah AS hw, arabic_noharokah AS hwn, arabic_root AS root, meaning AS m FROM $t',
              );
              break;
            default:
              maps = await txn.rawQuery(
                'SELECT word AS hw, word AS hwn, NULL AS root, meaning AS m FROM $t',
              );
          }
          final rows = <List<Object?>>[];
          for (final row in maps) {
            final raw = (row['hw'] ?? '').toString();
            final norm = _normalizeArabic((row['hwn'] ?? raw).toString());
            final root = row['root'] == null
                ? ''
                : _normalizeArabic(row['root'].toString());
            final meaning = (row['m'] ?? '').toString();
            if (raw.isEmpty && meaning.isEmpty) continue;
            rows.add([raw, norm, root, meaning, s.tableName]);
            if (rows.length >= 500) {
              await insertRows(rows);
              rows.clear();
            }
          }
          if (rows.isNotEmpty) {
            await insertRows(rows);
          }
        }

        await txn.insert('app_meta', {
          'key': 'fts_schema_version',
          'value': _kFtsSchemaVersion.toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        // Keep legacy flag for back-compat; read path ignores it.
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

  // Normalize Arabic (strip diacritics and unify common variants) for matching.
  // Delegates to [ranking.normalizeArabic] so the DB layer, the FTS layer
  // and the suggestion ranker agree on what "normalized" means.
  String _normalizeArabic(String input) => ranking.normalizeArabic(input);

  Future<Map<String, dynamic>?> _getRandomRow(
    Database db,
    String tableName, {
    Random? rng,
  }) async {
    final maxRowId = Sqflite.firstIntValue(
      await db.rawQuery('SELECT MAX(rowid) FROM $tableName'),
    );
    if (maxRowId == null || maxRowId <= 0) return null;
    final r = rng ?? _random;
    final seed = r.nextInt(maxRowId) + 1;
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

    // Sort by relevance using the shared scorer (same one the isolate uses
    // for suggestion re-ranking). Exact > normalized-exact > prefix > contains.
    allResults.sort(
      (a, b) => ranking.scoreSuggestion(query, a.word).compareTo(
        ranking.scoreSuggestion(query, b.word),
      ),
    );

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

  // FTS-backed search across all sources. Searches headword_raw /
  // headword_norm / root_norm — NOT meaning. Meaning is excluded from the
  // suggestion list because a single word in a long definition would
  // otherwise flood the dropdown and drown out real headword hits.
  //
  // Escapes the FTS5 query token to prevent the user's input from being
  // interpreted as an FTS operator (AND/OR/NEAR/etc).
  Future<List<Word>> _searchWordsFts(String query, int limit) async {
    if (!_ftsAvailable) return [];
    final db = await database;
    final qn = _normalizeArabic(query);
    try {
      await _ensureMetaTable(db);
      await _ensureFtsIndex(db);
      if (!_ftsAvailable) return [];
      final escapedRaw = _ftsEscape(query);
      final escapedNorm = _ftsEscape(qn);
      final match =
          'headword_norm:$escapedNorm* '
          'OR headword_raw:$escapedRaw* '
          'OR root_norm:$escapedNorm';
      final rows = await db.rawQuery(
        'SELECT headword_raw, headword_norm, meaning, source, '
        'bm25(entries_fts) AS rank FROM entries_fts '
        'WHERE entries_fts MATCH ? ORDER BY rank LIMIT ?',
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

  // Double-quote and escape internal quotes for FTS5 phrase queries.
  String _ftsEscape(String input) => text_clean.ftsEscape(input);

  // --- AI result cache -------------------------------------------------
  //
  // Words resolved via Gemini are expensive (network + billable) and the
  // answer for a single headword does not change between runs. We keep a
  // row per headword so the next lookup is instant even across launches.
  //
  // Returns null if there is no cached answer, or if the stored JSON is
  // corrupt (treated as a miss so callers fall through to the API).
  Future<Word?> getCachedAiWord(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'ai_cache',
      where: 'word = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final payload = rows.first['payload']?.toString() ?? '';
    if (payload.isEmpty) return null;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return Word.fromJson(json);
    } catch (e) {
      debugPrint('Discarding corrupt ai_cache row for "$trimmed": $e');
      await db.delete('ai_cache', where: 'word = ?', whereArgs: [trimmed]);
      return null;
    }
  }

  Future<void> cacheAiWord(String word, Word value) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    final db = await database;
    await db.insert(
      'ai_cache',
      {
        'word': trimmed,
        'payload': jsonEncode(value.toJson()),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  /// Recent searches, newest first.
  ///
  /// Previously this method did an O(N) serial `getWord` per row (which
  /// fans out into many SQL queries each), making the Library tab slow
  /// for long history lists. We now issue the lookups in parallel and
  /// skip the dictionary enrichment entirely — the Library UI only needs
  /// the query string; it re-resolves the full word when the user taps.
  Future<List<Word>> getSearchHistory({int limit = 10, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'search_history',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return [
      for (final m in maps)
        Word(word: m['query'] as String, meaning: '', source: null),
    ];
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

    // Generate a new WOD. Deterministic: the same day picks the same source
    // and seeded row. This also means the rotation visits every source
    // in a fixed cycle instead of bouncing on the wall-clock epoch ms.
    try {
      final sources = DictionarySource.searchableDictionaries;
      final dayOrdinal = wod_seed.dayOrdinalUtc(DateTime.parse(today));
      final sourceIndex =
          wod_seed.wodSourceIndex(dayOrdinal, sources.length);
      final chosenSource = sources[sourceIndex];
      final tableName = chosenSource.tableName;

      // Use a deterministic random for the row pick so debugging and
      // re-installs on the same day still produce the same WOD.
      final rowRng = Random(dayOrdinal);
      final row = await _getRandomRow(db, tableName, rng: rowRng);

      if (row != null) {
        final word = Word.fromMap(row, source: chosenSource);

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
          'value': chosenSource.tableName,
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
