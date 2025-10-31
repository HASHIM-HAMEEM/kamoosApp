// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:arabic_dictionary_app/main.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for tests with test environment variables
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(mergeWith: {
      'GEMINI_API_KEY': 'test_key_for_unit_tests',
    });
  });

  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app loads with the search screen
    expect(find.text('القاموس العربي'), findsOneWidget);
  });
}
