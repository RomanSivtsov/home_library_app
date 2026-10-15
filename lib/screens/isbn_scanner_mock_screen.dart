import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/book.dart';
import '../services/open_library_service.dart';
import '../widgets/book_cover_widget.dart';
import 'book_edit_screen.dart';

class IsbnScannerMockScreen extends StatefulWidget {
  const IsbnScannerMockScreen({super.key});

  @override
  State<IsbnScannerMockScreen> createState() => _IsbnScannerMockScreenState();
}

class _IsbnScannerMockScreenState extends State<IsbnScannerMockScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _useMockMode = false;
  bool _isProcessed = false;
  final TextEditingController _manualIsbnCtrl = TextEditingController();

  // Набор популярных книг с реальными кодами ISBN для Mock-режима и тестирования
  static final List<Book> _catalogByIsbn = [
    Book(
      id: 'mock_1',
      title: 'Чистый код: создание, анализ и рефакторинг',
      author: 'Роберт Мартин',
      genre: 'Программирование',
      year: 2008,
      isbn: '9780132350884',
      annotation: 'Классическое руководство по написанию чистого, поддерживаемого и надежного кода.',
      status: ReadingStatus.completed,
      rating: 5.0,
      coverColor: const Color(0xFF2E5A88),
    ),
    Book(
      id: 'mock_2',
      title: 'Дюна',
      author: 'Фрэнк Герберт',
      genre: 'Фантастика',
      year: 1965,
      isbn: '9780441172719',
      annotation: 'Культовый научно-фантастический роман о пустынной планете Арракис и пряности меланж.',
      status: ReadingStatus.reading,
      rating: 4.8,
      coverColor: const Color(0xFFB86B35),
    ),
    Book(
      id: 'mock_3',
      title: 'Паттерны объектно-ориентированного проектирования',
      author: 'Эрих Гамма, Ричард Хелм, Ральф Джонсон, Джон Влиссидес',
      genre: 'Программирование',
      year: 1994,
      isbn: '9780201633610',
      annotation: 'Каталог 23 классических паттернов проектирования архитектуры ПО от Банды Четырех (GoF).',
      status: ReadingStatus.reading,
      rating: 4.9,
      coverColor: const Color(0xFF37474F),
    ),
    Book(
      id: 'mock_4',
      title: '1984',
      author: 'Джордж Оруэлл',
      genre: 'Фантастика',
      year: 1949,
      isbn: '9780451524935',
      annotation: 'Знаменитый роман-антиутопия о тоталитарном государстве, Министерстве Правды и Большом Брате.',
      status: ReadingStatus.completed,
      rating: 4.9,
      coverColor: const Color(0xFF4A3B52),
    ),
    Book(
      id: 'mock_5',
      title: 'Грокаем алгоритмы',
      author: 'Адитья Бхаргава',
      genre: 'Программирование',
      year: 2016,
      isbn: '9781617292231',
      annotation: 'Иллюстрированное руководство по алгоритмам и структурам данных для программистов.',
      status: ReadingStatus.completed,
      rating: 4.7,
      coverColor: const Color(0xFF3B7A57),
    ),
  ];

  @override
  void dispose() {
    _scannerController.dispose();
    _manualIsbnCtrl.dispose();
    super.dispose();
  }

  void _resumeScanning() {
    setState(() => _isProcessed = false);
    if (!_useMockMode) {
      _scannerController.start();
    }
  }

  /// Обработка распознанного штрихкода ISBN и сетевой запрос к Open Library REST API
  Future<void> _handleScannedIsbn(String rawCode) async {
    if (_isProcessed) return;

    final cleanIsbn = OpenLibraryService.cleanIsbn(rawCode);

    if (!OpenLibraryService.isValidIsbn(cleanIsbn)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Код "$rawCode" не является книжным ISBN (ожидается 10 или 13 цифр)',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessed = true);
    await _scannerController.stop();

    if (!mounted) return;

    // Диалоговое окно индикации асинхронного REST API запроса
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Запрос к Open Library API...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ISBN: $cleanIsbn',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Book? resultBook;
    String? errorMessage;

    try {
      // Сетевой вызов через Async/Await
      resultBook = await OpenLibraryService().fetchBookByIsbn(cleanIsbn);
    } catch (e) {
      errorMessage = e.toString();
      // Проверяем локальный резервный список на случай отсутствия сети
      final matchedLocal = _catalogByIsbn.where((b) => b.isbn == cleanIsbn).firstOrNull;
      if (matchedLocal != null) {
        resultBook = matchedLocal.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        );
        errorMessage = null;
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Закрываем диалог загрузки
      }
    }

    if (!mounted) return;

    if (resultBook != null) {
      _showConfirmationSheet(resultBook);
    } else {
      _showNotFoundDialog(cleanIsbn, errorMessage ?? 'Книга не найдена');
    }
  }

  /// Диалог в случае ошибки сетевого запроса или отсутствия книги в базе
  void _showNotFoundDialog(String isbn, String errorMsg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.search_off_rounded, size: 48, color: Colors.orange),
        title: const Text('Книга не найдена в API'),
        content: Text(
          '$errorMsg\n\nВы можете внести данные книги для ISBN ($isbn) вручную.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resumeScanning();
            },
            child: const Text('Повторить сканирование'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final manualBook = await Navigator.push<Book>(
                context,
                MaterialPageRoute(
                  builder: (_) => BookEditScreen(
                    existingBook: Book(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: '',
                      author: '',
                      genre: 'Художественная литература',
                      year: DateTime.now().year,
                      isbn: isbn,
                      annotation: '',
                      status: ReadingStatus.planned,
                      rating: 4.5,
                      coverColor: const Color(0xFF4A6572),
                    ),
                  ),
                ),
              );
              if (manualBook != null && mounted) {
                Navigator.pop(context, manualBook);
              } else {
                _resumeScanning();
              }
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Ввести вручную'),
          ),
        ],
      ),
    );
  }

  /// Нижний диалог подтверждения с карточкой книги, превью обложки и опцией ручного редактирования
  void _showConfirmationSheet(Book scannedBook) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_done_rounded,
                  color: Colors.teal,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Данные получены из Open Library',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCoverWidget(
                  book: scannedBook,
                  width: 90,
                  height: 135,
                  showTitleOnCover: false,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scannedBook.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scannedBook.author,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(scannedBook.genre),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('${scannedBook.year} г.'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ISBN: ${scannedBook.isbn}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (scannedBook.annotation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scannedBook.annotation,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resumeScanning();
                    },
                    child: const Text('Заново'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // Переход к экрану ручного редактирования карточки
                      final editedBook = await Navigator.push<Book>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookEditScreen(existingBook: scannedBook),
                        ),
                      );
                      if (editedBook != null && mounted) {
                        Navigator.pop(context, editedBook);
                      } else {
                        _resumeScanning();
                      }
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Править'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, scannedBook);
                    },
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text('В библиотеку'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканирование ISBN'),
        actions: [
          if (!_useMockMode) ...[
            IconButton(
              icon: const Icon(Icons.flash_on_rounded),
              tooltip: 'Вспышка',
              onPressed: () => _scannerController.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch_rounded),
              tooltip: 'Переключить камеру',
              onPressed: () => _scannerController.switchCamera(),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Переключатель режима: Реальная камера / Программный Mock для эмулятора
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.camera_alt_rounded),
                  label: Text('Камера'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.qr_code_2_rounded),
                  label: Text('Mock / Тестовые ISBN'),
                ),
              ],
              selected: {_useMockMode},
              onSelectionChanged: (s) => setState(() => _useMockMode = s.first),
            ),
          ),
          Expanded(
            child: _useMockMode ? _buildMockEmulatorView() : _buildCameraView(),
          ),
        ],
      ),
    );
  }

  /// 1. Режим реальной камеры на базе пакета mobile_scanner
  Widget _buildCameraView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final raw = barcode.rawValue;
              if (raw != null && raw.isNotEmpty) {
                _handleScannedIsbn(raw);
                break;
              }
            }
          },
          errorBuilder: (context, error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_rounded,
                      size: 64,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Камера недоступна в текущем окружении',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Код ошибки: ${error.errorCode.name}.\nДля тестирования без физической камеры переключитесь в режим «Mock / Тестовые ISBN».',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => setState(() => _useMockMode = true),
                      icon: const Icon(Icons.qr_code_rounded),
                      label: const Text('Перейти к тестовым ISBN'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Визуальная рамка видоискателя для наведения на штрихкод ISBN
        Center(
          child: Container(
            width: 280,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.tealAccent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Наведите рамку на штрихкод ISBN (978...)',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Программный Mock с поиском и набором образцов для эмулятора и демонстрации
  Widget _buildMockEmulatorView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ручной ввод и отправка произвольного ISBN в Open Library API
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Отправка произвольного ISBN в Open Library API:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualIsbnCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Например: 9780132350884',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _handleScannedIsbn(_manualIsbnCtrl.text),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Запрос'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Тестовые образцы (нажмите для выполнения реального API-запроса):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        ..._catalogByIsbn.map((sample) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleScannedIsbn(sample.isbn),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Графический штрихкод ISBN
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: IsbnBarcodeGraphic(isbn: sample.isbn),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sample.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sample.author} (${sample.year})',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_sync_rounded,
                                size: 16,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Загрузить через Open Library REST API',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.w600,
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
            ),
          );
        }),
      ],
    );
  }
}
