class AppContacts {
  AppContacts._();

  static const String supportEmail = 'wenyafi@gmail.com';
  static const String privacyPolicyUrl =
      'https://alyafi0899.github.io/BuildEra-Construction-Store-POS/privacy-policy/';
  static const String accountDeletionUrl =
      'https://alyafi0899.github.io/BuildEra-Construction-Store-POS/account-deletion/';
  static const int accountDeletionSlaDays = 30;

  static const String userManualUrl =
      'https://github.com/alyafi0899/BuildEra-Assets/releases/download/1.2.5/Manual.Book.BuildEra.pdf';
  static const String excelImportTemplateUrl =
      'https://github.com/alyafi0899/BuildEra-Assets/releases/download/1.2.5/Upload.Item.Template.xlsx';

  static bool isConfigured(String url) {
    final trimmed = url.trim();
    return trimmed.isNotEmpty &&
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'));
  }
}
