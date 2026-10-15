import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_library_app/models/book.dart';
import 'package:home_library_app/services/database_service.dart';
import 'package:home_library_app/services/user_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Инициализация FFI для тестов SQLite в консоли/десктопе
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('UserPreferencesService (UserDefaults / SharedPreferences)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Загрузка дефолтных настроек интерфейса и цели чтения', () async {
      final prefs = await UserPreferencesService.instance.loadAll();
      expect(prefs.sortBy, equals(UserPreferencesService.defaultSortBy));
      expect(prefs.isGridView, equals(UserPreferencesService.defaultIsGridView));
      expect(prefs.yearlyGoal, equals(UserPreferencesService.defaultYearlyGoal));
    });

    test('Сохранение и чтение пользовательских настроек интерфейса', () async {
      final service = UserPreferencesService.instance;

      await service.setSortBy('year');
      expect(await service.getSortBy(), equals('year'));

      await service.setIsGridView(false);
      expect(await service.getIsGridView(), isFalse);

      await service.setYearlyGoal(25);
      expect(await service.getYearlyGoal(), equals(25));

      final all = await service.loadAll();
      expect(all.sortBy, equals('year'));
      expect(all.isGridView, isFalse);
      expect(all.yearlyGoal, equals(25));
    });
  });

  group('DatabaseService (Реляционная база данных SQLite)', () {
    late Database testDb;

    setUp(() async {
      // Создание in-memory реляционной БД для изолированного тестирования схемы
      testDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE authors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE genres (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE books (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                author_id INTEGER NOT NULL,
                genre_id INTEGER NOT NULL,
                year INTEGER NOT NULL,
                isbn TEXT NOT NULL,
                annotation TEXT NOT NULL,
                status TEXT NOT NULL,
                rating REAL NOT NULL,
                cover_color INTEGER NOT NULL,
                cover_url TEXT,
                FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE RESTRICT,
                FOREIGN KEY (genre_id) REFERENCES genres(id) ON DELETE RESTRICT
              )
            ''');
          },
        ),
      );
    });

    tearDown(() async {
      DatabaseService.instance.setTestDatabase(null);
      await testDb.close();
    });

    test('Создание реляционных записей в authors, genres и books с внешними ключами', () async {
      // 1. Вставляем автора и жанр
      final authorId = await testDb.insert('authors', {'name': 'Роберт Мартин'});
      final genreId = await testDb.insert('genres', {'name': 'Программирование'});

      expect(authorId, isPositive);
      expect(genreId, isPositive);

      // 2. Вставляем книгу со связями author_id и genre_id
      await testDb.insert('books', {
        'id': 'test_1',
        'title': 'Чистый код',
        'author_id': authorId,
        'genre_id': genreId,
        'year': 2008,
        'isbn': '9780132350884',
        'annotation': 'Книга по чистому коду',
        'status': ReadingStatus.completed.name,
        'rating': 5.0,
        'cover_color': 0xFF2E5A88,
        'cover_url': 'https://covers.openlibrary.org/b/isbn/9780132350884-L.jpg',
      });

      // 3. Выполняем SQL JOIN запрос
      final rows = await testDb.rawQuery('''
        SELECT 
          b.id,
          b.title,
          a.name AS author,
          g.name AS genre,
          b.year,
          b.isbn,
          b.annotation,
          b.status,
          b.rating,
          b.cover_color,
          b.cover_url
        FROM books b
        JOIN authors a ON b.author_id = a.id
        JOIN genres g ON b.genre_id = g.id
      ''');

      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['title'], equals('Чистый код'));
      expect(row['author'], equals('Роберт Мартин'));
      expect(row['genre'], equals('Программирование'));
      expect(row['year'], equals(2008));
      expect(row['status'], equals('completed'));
    });

    test('DatabaseService singleton операции вставки, обновления и удаления', () async {
      final dbService = DatabaseService.instance;
      dbService.setTestDatabase(testDb);

      final testBook = Book(
        id: 'db_test_100',
        title: 'Тестовая книга',
        author: 'Тестовый автор',
        genre: 'Тестовый жанр',
        year: 2026,
        isbn: '9781234567890',
        annotation: 'Аннотация для проверки БД',
        status: ReadingStatus.reading,
        rating: 4.8,
        coverColor: const Color(0xFF3B7A57),
      );

      // Добавление книги
      await dbService.insertOrUpdateBook(testBook);
      var list = await dbService.getBooks();
      expect(list.any((b) => b.id == 'db_test_100'), isTrue);

      final inserted = list.firstWhere((b) => b.id == 'db_test_100');
      expect(inserted.title, equals('Тестовая книга'));
      expect(inserted.author, equals('Тестовый автор'));
      expect(inserted.genre, equals('Тестовый жанр'));

      // Обновление книги
      final updatedBook = inserted.copyWith(title: 'Обновленная тестовая книга');
      await dbService.insertOrUpdateBook(updatedBook);

      list = await dbService.getBooks();
      final updated = list.firstWhere((b) => b.id == 'db_test_100');
      expect(updated.title, equals('Обновленная тестовая книга'));

      // Удаление книги
      await dbService.deleteBook('db_test_100');
      list = await dbService.getBooks();
      expect(list.any((b) => b.id == 'db_test_100'), isFalse);
    });

    test('Автоматическое предзаполнение начальными данными seedInitialDataIfEmpty', () async {
      final dbService = DatabaseService.instance;
      dbService.setTestDatabase(testDb);

      await dbService.clearAll();
      var list = await dbService.getBooks();
      expect(list, isEmpty);

      await dbService.seedInitialDataIfEmpty(initialBooks);
      list = await dbService.getBooks();
      expect(list.length, equals(initialBooks.length));
    });
  });
}
