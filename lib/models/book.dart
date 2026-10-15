import 'package:flutter/material.dart';

enum ReadingStatus {
  reading('Читаю', Icons.menu_book_rounded, Colors.orange),
  completed('Прочитано', Icons.check_circle_outline_rounded, Colors.green),
  planned('В планах', Icons.bookmark_border_rounded, Colors.blueGrey);

  final String label;
  final IconData icon;
  final Color color;
  const ReadingStatus(this.label, this.icon, this.color);
}

class Book {
  final String id;
  String title;
  String author;
  String genre;
  int year;
  String isbn;
  String annotation;
  ReadingStatus status;
  double rating;
  Color coverColor;
  String? coverUrl;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.genre,
    required this.year,
    required this.isbn,
    required this.annotation,
    required this.status,
    required this.rating,
    required this.coverColor,
    this.coverUrl,
  });

  /// Автоматическое получение обложки из Open Library по чистому ISBN
  String get resolvedCoverUrl {
    if (coverUrl != null && coverUrl!.trim().isNotEmpty) {
      return coverUrl!.trim();
    }
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    return 'https://covers.openlibrary.org/b/isbn/$cleanIsbn-L.jpg?default=false';
  }

  /// Создание копии сущности с возможностью модификации отдельных полей
  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? genre,
    int? year,
    String? isbn,
    String? annotation,
    ReadingStatus? status,
    double? rating,
    Color? coverColor,
    String? coverUrl,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      isbn: isbn ?? this.isbn,
      annotation: annotation ?? this.annotation,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      coverColor: coverColor ?? this.coverColor,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}

final List<Book> initialBooks = [
  Book(
    id: '1',
    title: 'Чистый код: создание, анализ и рефакторинг',
    author: 'Роберт Мартин',
    genre: 'Программирование',
    year: 2019,
    isbn: '9780132350884',
    annotation: 'Подробное руководство по написанию поддерживаемого, читаемого и надежного программного кода. Книга разбирает реальные сценарии рефакторинга, правила именования переменных, проектирования функций и организации модульных тестов.',
    status: ReadingStatus.completed,
    rating: 5.0,
    coverColor: const Color(0xFF2E5A88),
  ),
  Book(
    id: '2',
    title: 'Дюна',
    author: 'Фрэнк Герберт',
    genre: 'Фантастика',
    year: 2021,
    isbn: '9780441172719',
    annotation: 'Масштабная научно-фантастическая сага о пустынной планете Арракис, политических интригах Великих Домов и борьбе за контроль над самым ценным ресурсом Вселенной — пряностью меланж.',
    status: ReadingStatus.reading,
    rating: 4.8,
    coverColor: const Color(0xFFB86B35),
  ),
  Book(
    id: '3',
    title: 'Грокаем алгоритмы',
    author: 'Адитья Бхаргава',
    genre: 'Программирование',
    year: 2022,
    isbn: '9781617292231',
    annotation: 'Иллюстрированное пособие по базовым структурам данных, алгоритмам бинарного поиска, рекурсии, быстрой сортировки, хэш-таблицам и алгоритмам на графах.',
    status: ReadingStatus.completed,
    rating: 4.5,
    coverColor: const Color(0xFF3B7A57),
  ),
  Book(
    id: '4',
    title: 'Задача трех тел',
    author: 'Лю Цысинь',
    genre: 'Фантастика',
    year: 2020,
    isbn: '9780765377067',
    annotation: 'История первого контакта человечества с инопланетной цивилизацией Трисоляриса, стоящей на грани гибели из-за непредсказуемого движения трех солнц.',
    status: ReadingStatus.planned,
    rating: 4.0,
    coverColor: const Color(0xFF5D4E6D),
  ),
];
