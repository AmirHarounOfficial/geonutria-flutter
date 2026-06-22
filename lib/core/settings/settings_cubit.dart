import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/secure_session.dart';

class SettingsState extends Equatable {
  const SettingsState({required this.locale, required this.themeMode});

  final Locale locale;
  final ThemeMode themeMode;

  SettingsState copyWith({Locale? locale, ThemeMode? themeMode}) =>
      SettingsState(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
      );

  @override
  List<Object?> get props => [locale, themeMode];
}

/// Holds locale + theme, persisting both via [SecureSession].
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._session)
      : super(const SettingsState(
          locale: Locale('en'),
          themeMode: ThemeMode.system,
        ));

  final SecureSession _session;

  Future<void> load() async {
    final localeCode = await _session.readLocale();
    final themeStr = await _session.readThemeMode();
    emit(SettingsState(
      locale: Locale(localeCode ?? 'en'),
      themeMode: _parseTheme(themeStr),
    ));
  }

  Future<void> setLocale(String code) async {
    await _session.writeLocale(code);
    emit(state.copyWith(locale: Locale(code)));
  }

  Future<void> toggleLocale() =>
      setLocale(state.locale.languageCode == 'ar' ? 'en' : 'ar');

  Future<void> setThemeMode(ThemeMode mode) async {
    await _session.writeThemeMode(mode.name);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> toggleTheme() => setThemeMode(
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );

  ThemeMode _parseTheme(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
