import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/database_service.dart';
import '../services/user_preferences_service.dart';
import '../widgets/book_cover_widget.dart';
import 'book_detail_screen.dart';
import 'book_edit_screen.dart';
import 'isbn_scanner_mock_screen.dart';

class LibraryCatalogScreen extends StatefulWidget {
  const LibraryCatalogScreen({super.key});

  @override
  State<LibraryCatalogScreen> createState() => _LibraryCatalogScreenState();
}

class _LibraryCatalogScreenState extends State<LibraryCatalogScreen> {
  List<Book> _books = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedGenre = 'Все';
  ReadingStatus? _selectedStatus;
  bool _isGridView = UserPreferencesService.defaultIsGridView;
  String _sortBy = UserPreferencesService.defaultSortBy;
  int _yearlyGoal = UserPreferencesService.defaultYearlyGoal;

  @override
  void initState() {
    super.initState();
    _loadDataFromStorage();
  }

  /// Асинхронная загрузка данных из SQLite и настроек из SharedPreferences (UserDefaults)
  Future<void> _loadDataFromStorage() async {
    setState(() => _isLoading = true);

    try {
      // 1. Загрузка вспомогательного хранилища (UserDefaults)
      final prefs = await UserPreferencesService.instance.loadAll();

      // 2. Инициализация и загрузка из реляционной SQLite БД
      await DatabaseService.instance.seedInitialDataIfEmpty(initialBooks);
      final booksFromDb = await DatabaseService.instance.getBooks();

      if (mounted) {
        setState(() {
          _sortBy = prefs.sortBy;
          _isGridView = prefs.isGridView;
          _yearlyGoal = prefs.yearlyGoal;
          _books = booksFromDb;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _books = List.from(initialBooks);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки хранилища: $e')),
        );
      }
    }
  }

  List<String> get _availableGenres {
    final genres = _books.map((b) => b.genre).toSet().toList()..sort();
    return ['Все', ...genres];
  }

  List<Book> get _filteredBooks {
    final list = _books.where((book) {
      final matchesSearch =
          book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.author.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesGenre =
          _selectedGenre == 'Все' || book.genre == _selectedGenre;
      final matchesStatus =
          _selectedStatus == null || book.status == _selectedStatus;
      return matchesSearch && matchesGenre && matchesStatus;
    }).toList();

    list.sort((a, b) {
      switch (_sortBy) {
        case 'year':
          return b.year.compareTo(a.year);
        case 'rating':
          return b.rating.compareTo(a.rating);
        default:
          return a.title.compareTo(b.title);
      }
    });
    return list;
  }

  int get _completedBooksCount =>
      _books.where((b) => b.status == ReadingStatus.completed).length;

  /// Сохранение/обновление книги в реляционную SQLite базу данных
  Future<void> _addOrUpdateBook(Book book) async {
    await DatabaseService.instance.insertOrUpdateBook(book);
    final updatedList = await DatabaseService.instance.getBooks();
    if (mounted) {
      setState(() {
        _books = updatedList;
      });
    }
  }

  /// Удаление книги из реляционной SQLite базы данных
  Future<void> _deleteBook(String id) async {
    await DatabaseService.instance.deleteBook(id);
    final updatedList = await DatabaseService.instance.getBooks();
    if (mounted) {
      setState(() {
        _books = updatedList;
      });
    }
  }

  void _showGoalDialog() {
    final controller = TextEditingController(text: _yearlyGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Цель чтения на год'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Количество книг',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                setState(() => _yearlyGoal = value);
                // Сохраняем лимит в UserDefaults (SharedPreferences)
                UserPreferencesService.instance.setYearlyGoal(value);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBooks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Домашняя библиотека'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Сортировка',
            onSelected: (val) {
              setState(() => _sortBy = val);
              // Сохраняем параметр сортировки в UserDefaults (SharedPreferences)
              UserPreferencesService.instance.setSortBy(val);
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'title', child: Text('По названию')),
              PopupMenuItem(value: 'year', child: Text('По году издания')),
              PopupMenuItem(value: 'rating', child: Text('По оценке')),
            ],
          ),
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _isGridView ? 'Вид списка' : 'Виртуальная полка',
            onPressed: () {
              final newMode = !_isGridView;
              setState(() => _isGridView = newMode);
              // Сохраняем режим отображения в UserDefaults (SharedPreferences)
              UserPreferencesService.instance.setIsGridView(newMode);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Загрузка домашней библиотеки...'),
                ],
              ),
            )
          : SafeArea(
              child: Column(
          children: [
            _buildReadingGoalBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Поиск по названию или автору...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _buildFilterBar(),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Книги по заданным фильтрам не найдены',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final int columns = constraints.maxWidth > 900
                            ? 5
                            : constraints.maxWidth > 600
                            ? 3
                            : 2;

                        if (_isGridView) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: 0.64,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, idx) =>
                                _buildShelfCard(filtered[idx]),
                          );
                        } else {
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) =>
                                _buildListTile(filtered[idx]),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan_isbn',
            onPressed: () async {
              final scannedBook = await Navigator.push<Book>(
                context,
                MaterialPageRoute(
                  builder: (_) => const IsbnScannerMockScreen(),
                ),
              );
              if (scannedBook != null) {
                _addOrUpdateBook(scannedBook);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Книга «${scannedBook.title}» добавлена по ISBN!',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Сканер ISBN'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_manual',
            onPressed: () async {
              final createdBook = await Navigator.push<Book>(
                context,
                MaterialPageRoute(builder: (_) => const BookEditScreen()),
              );
              if (createdBook != null) {
                _addOrUpdateBook(createdBook);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Добавить вручную'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingGoalBanner() {
    final progress = (_completedBooksCount / _yearlyGoal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: InkWell(
        onTap: _showGoalDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Цель чтения на год: $_completedBooksCount из $_yearlyGoal книг',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          ...ReadingStatus.values.map((status) {
            final isSelected = _selectedStatus == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(status.icon, size: 18, color: status.color),
                label: Text(status.label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedStatus = selected ? status : null);
                },
              ),
            );
          }),
          const VerticalDivider(width: 16),
          ..._availableGenres.map((genre) {
            final isSelected = _selectedGenre == genre;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(genre),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedGenre = genre),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShelfCard(Book book) {
    return GestureDetector(
      onTap: () => _openBookDetails(book),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: BookCoverWidget(
                    book: book,
                    width: 115,
                    height: 165,
                    showTitleOnCover: false,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        book.status.icon,
                        size: 15,
                        color: book.status.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        book.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: book.status.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 16,
                      ),
                      Text(
                        book.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(Book book) {
    return Card(
      child: ListTile(
        onTap: () => _openBookDetails(book),
        leading: BookCoverWidget(
          book: book,
          width: 42,
          height: 60,
          showTitleOnCover: false,
        ),
        title: Text(
          book.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${book.author} • ${book.genre} (${book.year})'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                Text(book.rating.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              book.status.label,
              style: TextStyle(fontSize: 12, color: book.status.color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBookDetails(Book book) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(
          book: book,
          onUpdate: _addOrUpdateBook,
          onDelete: () {
            _deleteBook(book.id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
