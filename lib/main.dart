import 'package:flutter/material.dart';

import 'screens/library_catalog_screen.dart';
import 'services/database_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseService.initDesktopFfiIfNeeded();
  runApp(const HomeLibraryApp());
}

class HomeLibraryApp extends StatelessWidget {
  const HomeLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Домашняя библиотека',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6572),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const LibraryCatalogScreen(),
    );
  }
}
