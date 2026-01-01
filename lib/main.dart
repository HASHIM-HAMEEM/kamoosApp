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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final geminiKey = dotenv.env['GEMINI_API_KEY'];
    debugPrint(
      '🔑 Gemini API Key loaded: ${geminiKey != null && geminiKey.isNotEmpty ? "YES (${geminiKey.substring(0, 10)}...)" : "NO"}',
    );

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
            if (geminiKey != null && geminiKey.isNotEmpty) {
              try {
                debugPrint('✅ Creating ApiService with Gemini API key');
                return ApiService(apiKey: geminiKey);
              } catch (e) {
                debugPrint('❌ Failed to initialize ApiService: $e');
                return null;
              }
            }
            debugPrint('⚠️  ApiService not created: No API key found');
            return null;
          },
        ),
        ProxyProvider2<DatabaseService, ApiService?, SearchService>(
          update: (context, dbService, apiService, _) =>
              SearchService(databaseService: dbService, apiService: apiService),
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Qamus - Arabic Dictionary',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _themeMode,
            locale: settings.locale,
            supportedLocales: const [Locale('en'), Locale('ur'), Locale('ar')],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MainShell(onToggleTheme: _toggleTheme),
          );
        },
      ),
    );
  }
}
