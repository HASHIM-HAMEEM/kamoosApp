enum DictionarySource {
  all('الكل', 'all'),
  muashiroh('معجم المعاصرة', 'mujamul_muashiroh'),
  wasith('معجم الوسيط', 'mujamul_wasith'),
  muhith('معجم المحيط', 'mujamul_muhith'),
  shihah('معجم الصحاح', 'mujamul_shihah'),
  ghoni('معجم الغني', 'mujamul_ghoni'),
  lisanularab('لسان العرب', 'lisanularab'),
  ghoribulquran('غريب القرآن', 'ghoribulquran');

  final String arabicName;
  final String tableName;

  const DictionarySource(this.arabicName, this.tableName);

  static List<DictionarySource> get searchableDictionaries => [
        muashiroh,
        wasith,
        muhith,
        shihah,
        ghoni,
        lisanularab,
        ghoribulquran,
      ];
}
