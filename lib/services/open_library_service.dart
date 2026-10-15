import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/book.dart';

/// Базовое исключение сетевого слоя Open Library
sealed class OpenLibraryException implements Exception {
  final String message;
  const OpenLibraryException(this.message);

  @override
  String toString() => message;
}

/// Книга с указанным ISBN не найдена в каталоге
class BookNotFoundException extends OpenLibraryException {
  final String isbn;
  const BookNotFoundException(this.isbn)
      : super('Книга с ISBN "$isbn" не найдена в Open Library.');
}

/// Ошибка сетевого соединения или таймаут
class NetworkException extends OpenLibraryException {
  const NetworkException([String? message])
      : super(
          message ??
              'Не удалось связаться с сервером Open Library. Проверьте интернет-соединение.',
        );
}

/// Некорректный формат переданного ISBN
class InvalidIsbnException extends OpenLibraryException {
  final String rawCode;
  const InvalidIsbnException(this.rawCode)
      : super('Код "$rawCode" не является корректным ISBN-10 или ISBN-13.');
}

/// Сетевой сервис для работы со сторонним REST API Open Library на базе Async/Await
class OpenLibraryService {
  final http.Client _client;

  OpenLibraryService({http.Client? client}) : _client = client ?? http.Client();

  static const Duration requestTimeout = Duration(seconds: 12);

  /// Палитра для автоматического выбора акцентного цвета книги
  static const List<Color> _palette = [
    Color(0xFF2E5A88),
    Color(0xFFB86B35),
    Color(0xFF3B7A57),
    Color(0xFF5D4E6D),
    Color(0xFF8C2D41),
    Color(0xFF37474F),
    Color(0xFF1E4D6B),
    Color(0xFF4A3B52),
  ];

  /// Очистка строки ISBN от пробелов, дефисов и посторонних символов
  static String cleanIsbn(String rawValue) {
    return rawValue.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
  }

  /// Валидация формата ISBN (ISBN-10 или ISBN-13)
  static bool isValidIsbn(String rawValue) {
    final clean = cleanIsbn(rawValue);
    if (clean.length == 10) return true;
    if (clean.length == 13 &&
        (clean.startsWith('978') || clean.startsWith('979'))) {
      return true;
    }
    return false;
  }

  /// Основной асинхронный метод запроса метаданных книги по ISBN в REST API Open Library
  Future<Book> fetchBookByIsbn(String rawIsbn) async {
    final clean = cleanIsbn(rawIsbn);

    if (!isValidIsbn(clean)) {
      throw InvalidIsbnException(rawIsbn);
    }

    try {
      // 1. Первичный запрос к Search API (https://openlibrary.org/dev/docs/api/search)
      final searchUri = Uri.parse(
        'https://openlibrary.org/search.json?isbn=$clean&fields=key,title,author_name,first_publish_year,cover_i,subject,first_sentence,subtitle&limit=1',
      );

      final response = await _client.get(searchUri).timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody) as Map<String, dynamic>;
        final docs = data['docs'] as List?;

        if (docs != null && docs.isNotEmpty) {
          final doc = docs.first as Map<String, dynamic>;
          return await _parseDocToBook(clean, doc);
        }
      }

      // 2. Резервный запрос к Open Library Books API (jscmd=data)
      final fallbackBook = await _fetchFromBooksApi(clean);
      if (fallbackBook != null) {
        return fallbackBook;
      }

      throw BookNotFoundException(clean);
    } on OpenLibraryException {
      rethrow;
    } on SocketException {
      throw const NetworkException('Отсутствует интернет-соединение.');
    } on TimeoutException {
      throw const NetworkException(
        'Превышено время ожидания ответа от Open Library API.',
      );
    } on http.ClientException catch (e) {
      throw NetworkException('Сетевая ошибка HTTP: ${e.message}');
    } catch (e) {
      throw NetworkException('Не удалось загрузить книгу: $e');
    }
  }

  /// Парсинг документа из Open Library Search API в сущность Book
  Future<Book> _parseDocToBook(
    String cleanIsbn,
    Map<String, dynamic> doc,
  ) async {
    final title = (doc['title'] as String?)?.trim() ?? 'Книга ($cleanIsbn)';

    // Авторы
    final authorsList = (doc['author_name'] as List?)
        ?.map((a) => a.toString().trim())
        .where((a) => a.isNotEmpty)
        .toList();
    final author = (authorsList != null && authorsList.isNotEmpty)
        ? authorsList.join(', ')
        : 'Неизвестный автор';

    // Год издания
    final year = (doc['first_publish_year'] as int?) ?? DateTime.now().year;

    // Жанр / Тематика
    final subjects = (doc['subject'] as List?)
        ?.map((s) => s.toString())
        .toList();
    final genre = _mapSubjectToGenre(subjects);

    // Обложка: по cover_i или прямой ссылке на covers.openlibrary.org
    final coverI = doc['cover_i'];
    final coverUrl = coverI != null
        ? 'https://covers.openlibrary.org/b/id/$coverI-L.jpg'
        : 'https://covers.openlibrary.org/b/isbn/$cleanIsbn-L.jpg';

    // Попытка получить расширенную аннотацию из Works API
    String annotation = '';
    final workKey = doc['key'] as String?;
    if (workKey != null && workKey.startsWith('/works/')) {
      annotation = await _fetchWorkDescription(workKey);
    }

    if (annotation.isEmpty) {
      final firstSentences = doc['first_sentence'];
      if (firstSentences is List && firstSentences.isNotEmpty) {
        annotation = firstSentences.first.toString();
      } else if (firstSentences is String && firstSentences.isNotEmpty) {
        annotation = firstSentences;
      } else if (doc['subtitle'] != null &&
          doc['subtitle'].toString().isNotEmpty) {
        annotation = doc['subtitle'].toString();
      } else {
        annotation =
            'Книга автоматически получена из Open Library API по ISBN $cleanIsbn.';
      }
    }

    // Выбор цвета обложки на основе хэша ISBN
    final color = _palette[cleanIsbn.hashCode.abs() % _palette.length];

    return Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      author: author,
      genre: genre,
      year: year,
      isbn: cleanIsbn,
      annotation: annotation,
      status: ReadingStatus.planned,
      rating: 4.5,
      coverColor: color,
      coverUrl: coverUrl,
    );
  }

  /// Загрузка подробного описания из endpoint works/{workKey}.json
  Future<String> _fetchWorkDescription(String workKey) async {
    try {
      final uri = Uri.parse('https://openlibrary.org$workKey.json');
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decodedBody = utf8.decode(res.bodyBytes);
        final data = jsonDecode(decodedBody) as Map<String, dynamic>;
        final desc = data['description'];
        if (desc is String && desc.trim().isNotEmpty) {
          return desc.trim();
        } else if (desc is Map && desc['value'] != null) {
          return desc['value'].toString().trim();
        }
      }
    } catch (_) {
      // При ошибке или таймауте fallback к базовым полям
    }
    return '';
  }

  /// Резервный запрос через Books API
  Future<Book?> _fetchFromBooksApi(String cleanIsbn) async {
    try {
      final uri = Uri.parse(
        'https://openlibrary.org/api/books?bibkeys=ISBN:$cleanIsbn&format=json&jscmd=data',
      );
      final res = await _client.get(uri).timeout(requestTimeout);
      if (res.statusCode == 200) {
        final decodedBody = utf8.decode(res.bodyBytes);
        final data = jsonDecode(decodedBody) as Map<String, dynamic>;
        final bookData = data['ISBN:$cleanIsbn'] as Map<String, dynamic>?;

        if (bookData != null) {
          final title = bookData['title']?.toString() ?? 'Книга ($cleanIsbn)';
          final authors = (bookData['authors'] as List?)
              ?.map((a) => a['name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .join(', ');

          // Извлечение года
          int year = DateTime.now().year;
          final pubDate = bookData['publish_date']?.toString();
          if (pubDate != null) {
            final match = RegExp(r'\d{4}').firstMatch(pubDate);
            if (match != null) {
              year = int.tryParse(match.group(0)!) ?? year;
            }
          }

          final subjects = (bookData['subjects'] as List?)
              ?.map((s) => s['name']?.toString() ?? '')
              .toList();
          final genre = _mapSubjectToGenre(subjects);

          final cover = bookData['cover'] as Map<String, dynamic>?;
          final coverUrl = cover?['large']?.toString() ??
              cover?['medium']?.toString() ??
              'https://covers.openlibrary.org/b/isbn/$cleanIsbn-L.jpg';

          final notes = bookData['notes']?.toString();
          final color = _palette[cleanIsbn.hashCode.abs() % _palette.length];

          return Book(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            author: (authors != null && authors.isNotEmpty)
                ? authors
                : 'Неизвестный автор',
            genre: genre,
            year: year,
            isbn: cleanIsbn,
            annotation: (notes != null && notes.isNotEmpty)
                ? notes
                : 'Метаданные получены из Open Library Books API.',
            status: ReadingStatus.planned,
            rating: 4.5,
            coverColor: color,
            coverUrl: coverUrl,
          );
        }
      }
    } catch (_) {
      // Игнорируем и возвращаем null для последующего исключения BookNotFoundException
    }
    return null;
  }

  /// Преобразование англоязычных тегов Open Library в аккуратные жанры
  static String _mapSubjectToGenre(List<String>? subjects) {
    if (subjects == null || subjects.isEmpty) return 'Художественная литература';

    final text = subjects.join(' ').toLowerCase();

    if (text.contains('computer') ||
        text.contains('programming') ||
        text.contains('software') ||
        text.contains('agile') ||
        text.contains('algorithm') ||
        text.contains('data structures')) {
      return 'Программирование';
    }
    if (text.contains('science fiction') ||
        text.contains('space') ||
        text.contains('sci-fi') ||
        text.contains('fantasy') ||
        text.contains('dune')) {
      return 'Фантастика';
    }
    if (text.contains('history') ||
        text.contains('biography') ||
        text.contains('autobiography')) {
      return 'История и биография';
    }
    if (text.contains('science') ||
        text.contains('physics') ||
        text.contains('mathematics')) {
      return 'Наука и образование';
    }
    if (text.contains('psychology') || text.contains('philosophy')) {
      return 'Психология и философия';
    }
    if (text.contains('business') ||
        text.contains('economics') ||
        text.contains('management')) {
      return 'Бизнес и экономика';
    }
    if (text.contains('art') || text.contains('design')) {
      return 'Искусство и дизайн';
    }
    if (text.contains('thriller') ||
        text.contains('mystery') ||
        text.contains('detective')) {
      return 'Детектив и триллер';
    }

    // Если прямого совпадения нет, берем первый читаемый предмет
    final first = subjects.first.trim();
    if (first.length > 30) {
      return 'Художественная литература';
    }
    return first;
  }
}
