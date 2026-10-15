import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/open_library_service.dart';

class BookEditScreen extends StatefulWidget {
  final Book? existingBook;

  const BookEditScreen({super.key, this.existingBook});

  @override
  State<BookEditScreen> createState() => _BookEditScreenState();
}

class _BookEditScreenState extends State<BookEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _authorCtrl;
  late TextEditingController _genreCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _isbnCtrl;
  late TextEditingController _annotationCtrl;
  late ReadingStatus _status;
  late double _rating;
  late Color _selectedColor;
  String? _coverUrl;
  bool _isLoadingApi = false;

  static const List<Color> _palette = [
    Color(0xFF2E5A88),
    Color(0xFFB86B35),
    Color(0xFF3B7A57),
    Color(0xFF5D4E6D),
    Color(0xFF8C2D41),
    Color(0xFF37474F),
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.existingBook;
    _titleCtrl = TextEditingController(text: b?.title ?? '');
    _authorCtrl = TextEditingController(text: b?.author ?? '');
    _genreCtrl = TextEditingController(text: b?.genre ?? 'Художественная литература');
    _yearCtrl = TextEditingController(text: (b?.year ?? DateTime.now().year).toString());
    _isbnCtrl = TextEditingController(text: b?.isbn ?? '');
    _annotationCtrl = TextEditingController(text: b?.annotation ?? '');
    _status = b?.status ?? ReadingStatus.planned;
    _rating = b?.rating ?? 4.5;
    _selectedColor = b?.coverColor ?? _palette.first;
    _coverUrl = b?.coverUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _genreCtrl.dispose();
    _yearCtrl.dispose();
    _isbnCtrl.dispose();
    _annotationCtrl.dispose();
    super.dispose();
  }

  /// Асинхронная загрузка метаданных книги из Open Library REST API по введенному ISBN
  Future<void> _fetchFromOpenLibrary() async {
    final rawIsbn = _isbnCtrl.text.trim();
    if (rawIsbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите ISBN перед запросом к Open Library'),
        ),
      );
      return;
    }

    setState(() => _isLoadingApi = true);

    try {
      final fetchedBook = await OpenLibraryService().fetchBookByIsbn(rawIsbn);
      setState(() {
        _titleCtrl.text = fetchedBook.title;
        _authorCtrl.text = fetchedBook.author;
        _genreCtrl.text = fetchedBook.genre;
        _yearCtrl.text = fetchedBook.year.toString();
        _annotationCtrl.text = fetchedBook.annotation;
        _selectedColor = fetchedBook.coverColor;
        _coverUrl = fetchedBook.coverUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Данные книги «${fetchedBook.title}» загружены из Open Library!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingApi = false);
      }
    }
  }

  void _saveForm() {
    if (!_formKey.currentState!.validate()) return;

    final cleanIsbn = _isbnCtrl.text.trim();
    final book = Book(
      id: widget.existingBook?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      author: _authorCtrl.text.trim(),
      genre: _genreCtrl.text.trim().isEmpty ? 'Художественная литература' : _genreCtrl.text.trim(),
      year: int.tryParse(_yearCtrl.text.trim()) ?? DateTime.now().year,
      isbn: cleanIsbn,
      annotation: _annotationCtrl.text.trim(),
      status: _status,
      rating: _rating,
      coverColor: _selectedColor,
      coverUrl: _coverUrl,
    );

    Navigator.pop(context, book);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBook != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Редактирование карточки' : 'Новая книга'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Название книги',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorCtrl,
              decoration: const InputDecoration(
                labelText: 'Автор(ы)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите автора' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _genreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Жанр',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Год издания',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _isbnCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Код ISBN (10 или 13 цифр)',
                hintText: 'Например: 9780132350884',
                border: const OutlineInputBorder(),
                suffixIcon: _isLoadingApi
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.cloud_download_rounded),
                        tooltip: 'Автозаполнение по ISBN из Open Library API',
                        onPressed: _fetchFromOpenLibrary,
                      ),
              ),
            ),
            if (_coverUrl != null && _coverUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.image_rounded, size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Обложка привязана из Open Library',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _coverUrl = null),
                    child: const Text('Сбросить обложку'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<ReadingStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Статус чтения',
                border: OutlineInputBorder(),
              ),
              items: ReadingStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Цвет обложки (резервный фон)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: _palette.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: color,
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _annotationCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Аннотация / Описание',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saveForm,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Сохранить карточку'),
            ),
          ],
        ),
      ),
    );
  }
}
