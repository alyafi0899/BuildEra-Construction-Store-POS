enum AppLanguage {
  indonesian,
  english;

  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.indonesian:
        return 'id';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.indonesian:
        return 'Bahasa Indonesia';
    }
  }

  String get flag {
    switch (this) {
      case AppLanguage.english:
        return '🇺🇸';
      case AppLanguage.indonesian:
        return '🇮🇩';
    }
  }

  static AppLanguage fromCode(String? code) {
    if (code == 'en') return AppLanguage.english;
    return AppLanguage.indonesian;
  }
}
