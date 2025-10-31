import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'screens/search_screen.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/search_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final geminiKey = dotenv.env['GEMINI_API_KEY'];
    debugPrint('🔑 Gemini API Key loaded: ${geminiKey != null && geminiKey.isNotEmpty ? "YES (${geminiKey.substring(0, 10)}...)" : "NO"}');

    return MultiProvider(
      providers: [
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
          dispose: (_, dbService) => dbService.close(),
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
      child: MaterialApp(
        title: 'القاموس العربي',
        debugShowCheckedModeBanner: false,
        // Set RTL text direction for Arabic support
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl, // Right-to-left for Arabic
            child: child ?? Container(),
          );
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color(0xFF1A1A1A),
            brightness: Brightness.light,
            primary: Color(0xFF1A1A1A),
            secondary: Color(0xFF4A4A4A),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFD32F2F),
            onPrimary: Color(0xFFFFFFFF),
            onSecondary: Color(0xFFFFFFFF),
            onSurface: Color(0xFF1A1A1A),
            onError: Color(0xFFFFFFFF),
          ),
          fontFamily: 'Jameel Noori Nastaleeq',
          textTheme: ThemeData.light().textTheme.apply(
            fontFamily: 'Jameel Noori Nastaleeq',
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFFFAFAFA),
            foregroundColor: Color(0xFF1A1A1A),
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontFamily: 'Jameel Noori Nastaleeq',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          scaffoldBackgroundColor: Color(0xFFFAFAFA),
          cardTheme: CardThemeData(
            color: Color(0xFFFFFFFF),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A1A1A),
              foregroundColor: Color(0xFFFFFFFF),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFFFFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Color(0xFF1A1A1A),
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color(0xFFE0E0E0),
            brightness: Brightness.dark,
            primary: Color(0xFFE0E0E0),
            secondary: Color(0xFFB0B0B0),
            surface: Color(0xFF1A1A1A),
            error: Color(0xFFCF6679),
            onPrimary: Color(0xFF000000),
            onSecondary: Color(0xFF000000),
            onSurface: Color(0xFFE0E0E0),
            onError: Color(0xFF000000),
          ),
          fontFamily: 'Jameel Noori Nastaleeq',
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'Jameel Noori Nastaleeq',
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF0A0A0A),
            foregroundColor: Color(0xFFE0E0E0),
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontFamily: 'Jameel Noori Nastaleeq',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE0E0E0),
            ),
          ),
          scaffoldBackgroundColor: Color(0xFF0A0A0A),
          cardTheme: CardThemeData(
            color: Color(0xFF1A1A1A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Color(0xFF2A2A2A),
                width: 1,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE0E0E0),
              foregroundColor: Color(0xFF000000),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Color(0xFF2A2A2A),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Color(0xFF2A2A2A),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Color(0xFFE0E0E0),
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const SearchScreen(),
      ),
    );
  }
}
