import 'dictionary_source.dart';

class Word {
  int? id;
  String word;
  String meaning;
  String? meaningEn;
  String? meaningUr;
  String? rootWord;
  String? history;
  String? examples;
  String? relatedWords;
  DictionarySource? source;
  DateTime? createdAt;
  DateTime? updatedAt;
  int? surahNumber; // For Quran context (ghoribulquran)
  int? ayahNumber; // For Quran context (ghoribulquran)

  Word({
    this.id,
    required this.word,
    required this.meaning,
    this.meaningEn,
    this.meaningUr,
    this.rootWord,
    this.history,
    this.examples,
    this.relatedWords,
    this.source,
    this.createdAt,
    this.updatedAt,
    this.surahNumber,
    this.ayahNumber,
  });

  // Convert Word object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'meaning_en': meaningEn,
      'meaning_ur': meaningUr,
      'root_word': rootWord,
      'history': history,
      'examples': examples,
      'related_words': relatedWords,
      'source': source?.tableName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'surah_number': surahNumber,
      'ayah_number': ayahNumber,
    };
  }

  // Create a Word object from JSON
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'],
      word: json['word'] ?? '',
      meaning: json['meaning'] ?? json['meaning_ar'] ?? '',
      meaningEn: json['meaning_en'],
      meaningUr: json['meaning_ur'],
      rootWord: json['root_word'],
      history: json['history'],
      examples: json['examples'],
      relatedWords: json['related_words'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      surahNumber: json['surah_number'],
      ayahNumber: json['ayah_number'],
    );
  }

  // Create a Word object from database map with dictionary source context
  factory Word.fromMap(Map<String, dynamic> map, {DictionarySource? source}) {
    // Extract word based on source
    String extractWord() {
      if (source == DictionarySource.ghoni) {
        return map['arabic_word'] ?? map['arabic_noharokah'] ?? '';
      } else if (source == DictionarySource.lisanularab) {
        return map['arabic_noharokah'] ?? map['arabic_meanings'] ?? '';
      } else if (source == DictionarySource.ghoribulquran) {
        return map['arabic_noharokah'] ?? map['ayah'] ?? '';
      }
      return map['word'] ?? map['arabic_word'] ?? map['arabic_noharokah'] ?? '';
    }

    // Extract meaning based on source
    String extractMeaning() {
      if (source == DictionarySource.ghoni) {
        return map['arabic_meanings'] ?? map['meaning'] ?? '';
      } else if (source == DictionarySource.lisanularab) {
        return map['arabic_meanings'] ?? '';
      }
      return map['meaning'] ??
          map['arabic_meanings'] ??
          map['definition'] ??
          '';
    }

    // Extract root word
    String? extractRoot() {
      return map['arabic_root'] ?? map['root_word'] ?? map['root'];
    }

    // Extract examples/context
    String? extractExamples() {
      if (source == DictionarySource.ghoribulquran) {
        return map['ayah'];
      }
      return map['examples'] ?? map['example'] ?? map['usage_examples'];
    }

    // Extract history/context
    String? extractHistory() {
      if (source == DictionarySource.ghoribulquran) {
        final surahName = map['surah_name'] ?? '';
        final surahId = map['id_surah'] ?? '';
        final ayahId = map['id_ayah'] ?? '';
        if (surahName.isNotEmpty || surahId.toString().isNotEmpty) {
          return 'سورة $surahName ($surahId:$ayahId)';
        }
      }
      return map['history'] ??
          map['etymology'] ??
          map['origin'] ??
          map['tafsir'];
    }

    int? parseInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '');

    return Word(
      id: map['id'] ?? map['arabic_id'] ?? map['ID'],
      word: extractWord(),
      meaning: extractMeaning(),
      meaningEn: map['meaning_en'],
      meaningUr: map['meaning_ur'],
      rootWord: extractRoot(),
      history: extractHistory(),
      examples: extractExamples(),
      relatedWords: map['related_words'] ?? map['related'] ?? map['synonyms'],
      source: source,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is String
                ? DateTime.parse(map['created_at'])
                : DateTime.fromMillisecondsSinceEpoch(map['created_at']))
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is String
                ? DateTime.parse(map['updated_at'])
                : DateTime.fromMillisecondsSinceEpoch(map['updated_at']))
          : null,
      surahNumber: source == DictionarySource.ghoribulquran
          ? parseInt(map['id_surah'])
          : null,
      ayahNumber: source == DictionarySource.ghoribulquran
          ? parseInt(map['id_ayah'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Word &&
        other.word == word &&
        other.meaning == meaning &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(word, meaning, source);
}
