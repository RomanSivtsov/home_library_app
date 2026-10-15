import 'package:flutter_test/flutter_test.dart';
import 'package:home_library_app/main.dart';
import 'package:home_library_app/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('HomeLibraryApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    DatabaseService.initDesktopFfiIfNeeded();

    await tester.pumpWidget(const HomeLibraryApp());
    // Ждем выполнения асинхронной инициализации
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Домашняя библиотека'), findsOneWidget);
  });
}
