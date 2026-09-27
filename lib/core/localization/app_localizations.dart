import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'ui_labels.dart';

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

  String label(String english) {
    if (!isRtl) return english;
    if (arabicUiLabels.containsKey(english)) return arabicUiLabels[english]!;
    for (final entry in AppStrings.values['en']!.entries) {
      if (entry.value == english) return AppStrings.values['ar']![entry.key]!;
    }
    // Leaf model labels use "Plant - Disease"; translate each known component.
    if (english.contains(' - ')) {
      return english.split(' - ').map((part) => label(part.trim())).join(' — ');
    }
    return english;
  }

  /// Server messages have no guaranteed locale. Never leak the other language
  /// into an error banner; detailed diagnostics remain in the debug log.
  String errorText(String message) {
    if (isRtl) {
      if (arabicUiLabels.containsKey(message)) return arabicUiLabels[message]!;
      if (!RegExp(r'[A-Za-z]').hasMatch(message)) return message;
      return tr('error_generic');
    }
    return RegExp(r'[\u0600-\u06ff]').hasMatch(message)
        ? tr('error_generic')
        : message;
  }

  String tr(String key) {
    final lang =
        AppStrings.values[locale.languageCode] ?? AppStrings.values['en']!;
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
  String ui(String english) => AppLocalizations.of(this).label(english);
  String errorText(String message) =>
      AppLocalizations.of(this).errorText(message);
  String tr(String key) => AppLocalizations.of(this).tr(key);
  bool get isRtl => AppLocalizations.of(this).isRtl;
  Locale get locale => Localizations.localeOf(this);
}
