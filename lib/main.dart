import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/search_service.dart';
import 'services/settings_service.dart';
import 'ui/theme/app_theme.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setHighRefreshRate();
  //
  // Note: .env is bundled as a Flutter asset (see pubspec.yaml). This means
  // the Gemini API key ships inside release builds and can be extracted from
  // the APK/IPA. Before public release, move the key behind a proxy endpoint
  // or inject it via --dart-define at build time.
  //
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

Future<void> _setHighRefreshRate() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    debugPrint('Failed to set high refresh rate: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final geminiKey = dotenv.env['GEMINI_API_KEY'];

    return MultiProvider(
      providers: [
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
          dispose: (_, dbService) => dbService.close(),
        ),
        ChangeNotifierProxyProvider<DatabaseService, SettingsService>(
          create: (context) => SettingsService(
            Provider.of<DatabaseService>(context, listen: false),
          ),
          update: (context, db, previous) => previous ?? SettingsService(db),
        ),
        Provider<ApiService?>(
          create: (_) {
            if (geminiKey == null || geminiKey.isEmpty) {
              debugPrint('ApiService not created: no Gemini API key in .env');
              return null;
            }
            return ApiService(apiKey: geminiKey);
          },
        ),
        ProxyProvider2<DatabaseService, ApiService?, SearchService>(
          update: (context, dbService, apiService, _) =>
              SearchService(databaseService: dbService, apiService: apiService),
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          final base = MediaQuery.of(context);
          return MediaQuery(
            // Fold the user's preferred scale into MediaQuery's base
            // textScaler so every Text() in the tree picks it up.
            data: base.copyWith(
              textScaler: base.textScaler
                  .clamp(
                    minScaleFactor: settings.textScale,
                    maxScaleFactor: settings.textScale,
                  ),
            ),
            child: MaterialApp(
              title: 'Qamus - Arabic Dictionary',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: settings.themeMode,
              locale: settings.locale,
              supportedLocales: const [Locale('en'), Locale('ur'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const MainShell(),
            ),
          );
        },
      ),
    );
  }
}
