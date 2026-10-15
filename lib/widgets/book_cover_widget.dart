import 'package:flutter/material.dart';

import '../models/book.dart';

class BookCoverWidget extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final bool showTitleOnCover;

  const BookCoverWidget({
    super.key,
    required this.book,
    this.width = 130,
    this.height = 190,
    this.showTitleOnCover = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(3, 5)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Загрузка реальной обложки по ISBN / URL с резервной 3D-обложкой
          Image.network(
            book.resolvedCoverUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildStylizedFallbackCover(),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildStylizedFallbackCover(isLoading: true);
            },
          ),
          // 2. Эффект корешка книги слева
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStylizedFallbackCover({bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            book.coverColor,
            Color.lerp(book.coverColor, Colors.black, 0.4)!,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.genre.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : Icon(
                    Icons.auto_stories_rounded,
                    size: width * 0.32,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
          ),
          if (showTitleOnCover)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 9,
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Графическая визуализация штрихкода ISBN
class IsbnBarcodeGraphic extends StatelessWidget {
  final String isbn;

  const IsbnBarcodeGraphic({super.key, required this.isbn});

  @override
  Widget build(BuildContext context) {
    final codeUnits = isbn.isEmpty ? [48] : isbn.codeUnits;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(32, (index) {
              final unit = codeUnits[index % codeUnits.length];
              final isThick = (unit + index) % 3 == 0;
              final isGap = (unit + index) % 5 == 0;
              return Container(
                width: isThick ? 3.0 : 1.5,
                margin: EdgeInsets.only(right: isGap ? 3.0 : 1.5),
                color: Colors.black87,
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isbn,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
