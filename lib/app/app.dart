import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/app_theme.dart';
import '../core/localization/app_localizations.dart';
import '../core/settings/settings_cubit.dart';
import '../features/auth/bloc/auth_cubit.dart';
import 'app_router.dart';

class GeoNutriaApp extends StatefulWidget {
  const GeoNutriaApp({super.key});

  @override
  State<GeoNutriaApp> createState() => _GeoNutriaAppState();
}

class _GeoNutriaAppState extends State<GeoNutriaApp> {
  late final _router = buildRouter(context.read<AuthCubit>());

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        return MaterialApp.router(
          title: 'GeoNutria',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          locale: settings.locale,
          routerConfig: _router,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
