import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/book.dart';

/// Сервис реляционной базы данных.
/// Поддерживает:
/// 1. SQLite (через sqflite_common_ffi на Windows/Linux/macOS и нативный sqflite на Android/iOS).
/// 2. Реляционное веб-хранилище (на Web в Chrome/Edge со связанными таблицами authors, genres, books).
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'home_library.db';
  static const int _dbVersion = 1;

  Database? _sqliteDb;
  bool _useWebStorage = kIsWeb;

  /// Инъекция БД для тестов
  @visibleForTesting
  void setTestDatabase(Database? db) {
    _sqliteDb = db;
    _useWebStorage = false;
  }

  /// Инициализация движка SQLite для десктопа (Windows / Linux)
  static void initDesktopFfiIfNeeded() {
    if (!kIsWeb) {
      try {
        if (Platform.isWindows || Platform.isLinux) {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
        }
      } catch (_) {
        // Игнорируем в окружениях без dart:io
      }
    }
  }

  /// Получение активного SQLite DatabaseFactory
  DatabaseFactory _getDatabaseFactory() {
    if (!kIsWeb) {
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          return databaseFactoryFfi;
        }
      } catch (_) {}
    }
    return databaseFactory;
  }

  Future<Database?> _getSqliteDatabase() async {
    if (_sqliteDb != null) return _sqliteDb;
    if (_useWebStorage) return null;

    try {
      final factory = _getDatabaseFactory();

      String dbPath;
      try {
        final docDir = await getApplicationDocumentsDirectory();
        dbPath = p.join(docDir.path, _dbName);
      } catch (_) {
        try {
          final dbDir = await factory.getDatabasesPath();
          dbPath = p.join(dbDir, _dbName);
        } catch (_) {
          dbPath = inMemoryDatabasePath;
        }
      }

      _sqliteDb = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _onCreate,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      return _sqliteDb;
    } catch (e) {
      // При ошибке платформы (например, в браузере или при отсутствии dll) переключаемся на реляционный веб-адаптер
      _useWebStorage = true;
      return null;
    }
  }

  /// Создание схемы реляционной SQLite БД
  Future<void> _onCreate(Database db, int version) async {
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
  }

  /// Загрузка списка книг
  Future<List<Book>> getBooks() async {
    final db = await _getSqliteDatabase();
    if (db != null) {
      return await _getBooksFromSqlite(db);
    }
    return await _getBooksFromRelationalWeb();
  }

  /// Чтение книг из SQLite через SQL JOIN
  Future<List<Book>> _getBooksFromSqlite(Database db) async {
    final results = await db.rawQuery('''
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
      ORDER BY b.title ASC
    ''');

    return results.map((row) {
      final statusName = row['status'] as String? ?? 'planned';
      final status = ReadingStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => ReadingStatus.planned,
      );
      final colorInt = row['cover_color'] as int? ?? 0xFF4A6572;

      return Book(
        id: row['id'] as String,
        title: row['title'] as String,
        author: row['author'] as String,
        genre: row['genre'] as String,
        year: row['year'] as int,
        isbn: row['isbn'] as String,
        annotation: row['annotation'] as String,
        status: status,
        rating: (row['rating'] as num).toDouble(),
        coverColor: Color(colorInt),
        coverUrl: row['cover_url'] as String?,
      );
    }).toList();
  }

  /// Сохранение (вставка или обновление) книги
  Future<void> insertOrUpdateBook(Book book) async {
    final db = await _getSqliteDatabase();
    if (db != null) {
      await _insertOrUpdateSqlite(db, book);
    } else {
      await _insertOrUpdateRelationalWeb(book);
    }
  }

  Future<void> _insertOrUpdateSqlite(Database db, Book book) async {
    final authorId = await _getOrCreateAuthorIdSqlite(db, book.author);
    final genreId = await _getOrCreateGenreIdSqlite(db, book.genre);

    final values = {
      'id': book.id,
      'title': book.title,
      'author_id': authorId,
      'genre_id': genreId,
      'year': book.year,
      'isbn': book.isbn,
      'annotation': book.annotation,
      'status': book.status.name,
      'rating': book.rating,
      'cover_color': book.coverColor.toARGB32(),
      'cover_url': book.coverUrl,
    };

    await db.insert(
      'books',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> _getOrCreateAuthorIdSqlite(Database db, String authorName) async {
    final trimmed = authorName.trim().isEmpty ? 'Неизвестный автор' : authorName.trim();
    final existing = await db.query(
      'authors',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }
    return await db.insert(
      'authors',
      {'name': trimmed},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> _getOrCreateGenreIdSqlite(Database db, String genreName) async {
    final trimmed = genreName.trim().isEmpty ? 'Художественная литература' : genreName.trim();
    final existing = await db.query(
      'genres',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }
    return await db.insert(
      'genres',
      {'name': trimmed},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Удаление книги
  Future<void> deleteBook(String id) async {
    final db = await _getSqliteDatabase();
    if (db != null) {
      await db.delete('books', where: 'id = ?', whereArgs: [id]);
    } else {
      await _deleteRelationalWeb(id);
    }
  }

  /// Предзаполнение стартовой коллекцией, если база пустая
  Future<void> seedInitialDataIfEmpty(List<Book> initial) async {
    final existing = await getBooks();
    if (existing.isEmpty) {
      for (final book in initial) {
        await insertOrUpdateBook(book);
      }
    }
  }

  // =========================================================================
  // РЕЛЯЦИОННОЕ ХРАНИЛИЩЕ ДЛЯ WEB / FALLBACK
  // Реализует такую же реляционную структуру: authors, genres, books
  // =========================================================================

  static const String _webKeyAuthors = 'rel_db_authors';
  static const String _webKeyGenres = 'rel_db_genres';
  static const String _webKeyBooks = 'rel_db_books';

  Future<List<Book>> _getBooksFromRelationalWeb() async {
    final prefs = await SharedPreferences.getInstance();

    final authorsJson = prefs.getString(_webKeyAuthors) ?? '{}';
    final genresJson = prefs.getString(_webKeyGenres) ?? '{}';
    final booksJson = prefs.getString(_webKeyBooks) ?? '[]';

    final Map<String, dynamic> authors = jsonDecode(authorsJson);
    final Map<String, dynamic> genres = jsonDecode(genresJson);
    final List<dynamic> booksList = jsonDecode(booksJson);

    return booksList.map((item) {
      final map = item as Map<String, dynamic>;
      final authorId = map['author_id'].toString();
      final genreId = map['genre_id'].toString();

      final authorName = authors[authorId] as String? ?? 'Неизвестный автор';
      final genreName = genres[genreId] as String? ?? 'Художественная литература';

      final statusName = map['status'] as String? ?? 'planned';
      final status = ReadingStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => ReadingStatus.planned,
      );

      return Book(
        id: map['id'] as String,
        title: map['title'] as String,
        author: authorName,
        genre: genreName,
        year: map['year'] as int? ?? DateTime.now().year,
        isbn: map['isbn'] as String? ?? '',
        annotation: map['annotation'] as String? ?? '',
        status: status,
        rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
        coverColor: Color(map['cover_color'] as int? ?? 0xFF4A6572),
        coverUrl: map['cover_url'] as String?,
      );
    }).toList();
  }

  Future<void> _insertOrUpdateRelationalWeb(Book book) async {
    final prefs = await SharedPreferences.getInstance();

    final authorsJson = prefs.getString(_webKeyAuthors) ?? '{}';
    final genresJson = prefs.getString(_webKeyGenres) ?? '{}';
    final booksJson = prefs.getString(_webKeyBooks) ?? '[]';

    final Map<String, dynamic> authors = jsonDecode(authorsJson);
    final Map<String, dynamic> genres = jsonDecode(genresJson);
    final List<dynamic> booksList = jsonDecode(booksJson);

    // 1. Поиск или создание автора
    String? authorId;
    for (final entry in authors.entries) {
      if (entry.value.toString().toLowerCase() == book.author.toLowerCase()) {
        authorId = entry.key;
        break;
      }
    }
    if (authorId == null) {
      authorId = (authors.length + 1).toString();
      authors[authorId] = book.author.trim();
      await prefs.setString(_webKeyAuthors, jsonEncode(authors));
    }

    // 2. Поиск или создание жанра
    String? genreId;
    for (final entry in genres.entries) {
      if (entry.value.toString().toLowerCase() == book.genre.toLowerCase()) {
        genreId = entry.key;
        break;
      }
    }
    if (genreId == null) {
      genreId = (genres.length + 1).toString();
      genres[genreId] = book.genre.trim();
      await prefs.setString(_webKeyGenres, jsonEncode(genres));
    }

    // 3. Сохранение книги с внешними ключами author_id и genre_id
    final bookData = {
      'id': book.id,
      'title': book.title,
      'author_id': int.parse(authorId),
      'genre_id': int.parse(genreId),
      'year': book.year,
      'isbn': book.isbn,
      'annotation': book.annotation,
      'status': book.status.name,
      'rating': book.rating,
      'cover_color': book.coverColor.toARGB32(),
      'cover_url': book.coverUrl,
    };

    final existingIndex = booksList.indexWhere((b) => b['id'] == book.id);
    if (existingIndex >= 0) {
      booksList[existingIndex] = bookData;
    } else {
      booksList.add(bookData);
    }

    await prefs.setString(_webKeyBooks, jsonEncode(booksList));
  }

  Future<void> _deleteRelationalWeb(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final booksJson = prefs.getString(_webKeyBooks) ?? '[]';
    final List<dynamic> booksList = jsonDecode(booksJson);

    booksList.removeWhere((b) => b['id'] == id);
    await prefs.setString(_webKeyBooks, jsonEncode(booksList));
  }

  /// Очистка всех данных (для тестов)
  Future<void> clearAll() async {
    final db = await _getSqliteDatabase();
    if (db != null) {
      await db.delete('books');
      await db.delete('authors');
      await db.delete('genres');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_webKeyBooks);
    await prefs.remove(_webKeyAuthors);
    await prefs.remove(_webKeyGenres);
  }
}
