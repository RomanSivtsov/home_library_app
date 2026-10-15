import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../widgets/book_cover_widget.dart';
import 'book_edit_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;
  final ValueChanged<Book> onUpdate;
  final VoidCallback onDelete;

  const BookDetailScreen({
    super.key,
    required this.book,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late Book _book;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  void _updateRating(double newRating) {
    setState(() => _book.rating = newRating);
    widget.onUpdate(_book);
  }

  void _updateStatus(ReadingStatus newStatus) {
    setState(() => _book.status = newStatus);
    widget.onUpdate(_book);
  }

  String _ratingDescription(double rating) {
    if (rating >= 4.8) return 'Шедевр, обязательно к прочтению';
    if (rating >= 4.0) return 'Отличная книга, рекомендую';
    if (rating >= 3.0) return 'Неплохо, на один раз';
    return 'Не оправдала ожиданий';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка книги'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Редактировать карточку',
            onPressed: () async {
              final updated = await Navigator.push<Book>(
                context,
                MaterialPageRoute(
                  builder: (_) => BookEditScreen(existingBook: _book),
                ),
              );
              if (updated != null) {
                setState(() => _book = updated);
                widget.onUpdate(updated);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Удалить из библиотеки',
            onPressed: widget.onDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ВЕРХНИЙ БЛОК: ОБЛОЖКА И ОСНОВНЫЕ СВЕДЕНИЯ
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCoverWidget(book: _book, width: 130, height: 195),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _book.genre,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _book.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _book.author,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Год издания: ${_book.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. ПЕРЕКЛЮЧАТЕЛЬ СТАТУСА ЧТЕНИЯ
            const Text(
              'Статус чтения',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ReadingStatus>(
              segments: ReadingStatus.values
                  .map(
                    (s) => ButtonSegment<ReadingStatus>(
                      value: s,
                      label: Text(s.label),
                      icon: Icon(s.icon),
                    ),
                  )
                  .toList(),
              selected: {_book.status},
              onSelectionChanged: (selection) => _updateStatus(selection.first),
            ),
            const SizedBox(height: 24),

            // 3. ЛИЧНАЯ ОЦЕНКА ПОЛЬЗОВАТЕЛЯ
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Личная оценка пользователя',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_book.rating.toStringAsFixed(1)} / 5.0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Интерактивные звезды
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1.0;
                        final isFull = _book.rating >= starValue;
                        final isHalf =
                            !isFull && _book.rating >= (starValue - 0.5);
                        return IconButton(
                          iconSize: 36,
                          onPressed: () => _updateRating(starValue),
                          icon: Icon(
                            isFull
                                ? Icons.star_rounded
                                : isHalf
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber.shade600,
                          ),
                        );
                      }),
                    ),
                    // Точная подстройка слайдером
                    Slider(
                      value: _book.rating,
                      min: 1.0,
                      max: 5.0,
                      divisions: 40,
                      label: _book.rating.toStringAsFixed(1),
                      onChanged: _updateRating,
                    ),
                    Center(
                      child: Text(
                        _ratingDescription(_book.rating),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. АННОТАЦИЯ К КНИГЕ
            const Text(
              'Аннотация',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                _book.annotation.isNotEmpty
                    ? _book.annotation
                    : 'Аннотация к данной книге не указана.',
                style: const TextStyle(fontSize: 15, height: 1.55),
              ),
            ),
            const SizedBox(height: 24),

            // 5. КАРТОЧКА ISBN И ШТРИХКОД
            const Text(
              'Идентификатор издания (ISBN)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  IsbnBarcodeGraphic(isbn: _book.isbn),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _book.isbn));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ISBN ${_book.isbn} скопирован'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Скопировать ISBN'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
