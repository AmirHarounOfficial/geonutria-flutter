import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Lightweight localization: looks a key up in [AppStrings] for the active
/// locale, falling back to English and finally to the key itself. Modeled on
/// the web `getTranslation(lang)` helper.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [Locale('en'), Locale('ar')];

  bool get isRtl => locale.languageCode == 'ar';

  String tr(String key) {
    final lang = AppStrings.values[locale.languageCode] ?? AppStrings.values['en']!;
    return lang[key] ?? AppStrings.values['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings.values.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// `context.tr('key')` sugar.
extension AppLocalizationsX on BuildContext {
  String tr(String key) => AppLocalizations.of(this).tr(key);
  bool get isRtl => AppLocalizations.of(this).isRtl;
  Locale get locale => Localizations.localeOf(this);
}
