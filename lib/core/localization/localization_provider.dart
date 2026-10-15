import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/providers/app_settings_provider.dart';
import 'app_strings.dart';

final appStringsProvider = Provider<AppStrings>((ref) {
  final appSettings = ref.watch(appSettingsProvider);
  return AppStrings(appSettings.appLanguage);
});
