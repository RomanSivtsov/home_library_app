import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_library_app/services/open_library_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenLibraryService - валидация и очистка ISBN', () {
    test('cleanIsbn очищает дефисы и пробелы', () {
      expect(
        OpenLibraryService.cleanIsbn('978-0-13-235088-4'),
        equals('9780132350884'),
      );
      expect(
        OpenLibraryService.cleanIsbn(' 0-201-63361-2 '),
        equals('0201633612'),
      );
      expect(
        OpenLibraryService.cleanIsbn('0-19-853453-1'),
        equals('0198534531'),
      );
    });

    test('isValidIsbn распознает валидные ISBN-10 и ISBN-13', () {
      expect(OpenLibraryService.isValidIsbn('9780132350884'), isTrue);
      expect(OpenLibraryService.isValidIsbn('9791234567890'), isTrue);
      expect(OpenLibraryService.isValidIsbn('0201633612'), isTrue);
    });

    test('isValidIsbn отклоняет некорректные коды', () {
      expect(OpenLibraryService.isValidIsbn('12345'), isFalse);
      expect(OpenLibraryService.isValidIsbn('1234567890123'), isFalse); // не начинается с 978/979
      expect(OpenLibraryService.isValidIsbn(''), isFalse);
    });
  });

  group('OpenLibraryService - сетевой слой REST API', () {
    test('Успешный парсинг ответа Search API в сущность Book', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('search.json')) {
          final sampleResponse = {
            'numFound': 1,
            'docs': [
              {
                'key': '/works/OL17618370W',
                'title': 'Clean Code',
                'author_name': ['Robert C. Martin'],
                'first_publish_year': 2008,
                'cover_i': 8065615,
                'subject': ['Computer programming', 'Software engineering'],
                'first_sentence': ['Even bad code can function.'],
                'subtitle': 'A Handbook of Agile Software Craftsmanship',
              }
            ]
          };
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleResponse)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path.contains('works')) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'description': 'Полное описание книги Чистый Код'}),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = OpenLibraryService(client: mockClient);
      final book = await service.fetchBookByIsbn('9780132350884');

      expect(book.title, equals('Clean Code'));
      expect(book.author, equals('Robert C. Martin'));
      expect(book.year, equals(2008));
      expect(book.genre, equals('Программирование'));
      expect(book.isbn, equals('9780132350884'));
      expect(book.coverUrl, contains('8065615-L.jpg'));
      expect(book.annotation, equals('Полное описание книги Чистый Код'));
    });

    test('Резервный запрос через Books API при пустом Search API', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('search.json')) {
          return http.Response(jsonEncode({'numFound': 0, 'docs': []}), 200);
        } else if (request.url.path.contains('books')) {
          final booksResponse = {
            'ISBN:9780132350884': {
              'title': 'Clean Code Fallback',
              'authors': [
                {'name': 'Robert Martin'}
              ],
              'publish_date': 'August 2008',
              'subjects': [
                {'name': 'Programming'}
              ],
              'notes': 'Book notes from API',
            }
          };
          return http.Response.bytes(
            utf8.encode(jsonEncode(booksResponse)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = OpenLibraryService(client: mockClient);
      final book = await service.fetchBookByIsbn('9780132350884');

      expect(book.title, equals('Clean Code Fallback'));
      expect(book.author, equals('Robert Martin'));
      expect(book.year, equals(2008));
      expect(book.genre, equals('Программирование'));
    });

    test('Выбрасывает BookNotFoundException, если книга отсутствует в API', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'numFound': 0, 'docs': []}), 200);
      });

      final service = OpenLibraryService(client: mockClient);

      expect(
        () => service.fetchBookByIsbn('9780000000000'),
        throwsA(isA<BookNotFoundException>()),
      );
    });

    test('Выбрасывает InvalidIsbnException при передаче недопустимого формата', () async {
      final service = OpenLibraryService();
      expect(
        () => service.fetchBookByIsbn('abc'),
        throwsA(isA<InvalidIsbnException>()),
      );
    });
  });
}
