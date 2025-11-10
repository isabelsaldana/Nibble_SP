import 'package:flutter/material.dart';

class ImageGalleryPage extends StatefulWidget {
  const ImageGalleryPage({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTag,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String heroTag;

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  late final PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // --------- swipeable, zoomable images ----------
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];

              final image = InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white),
                  ),
                ),
              );

              // Only the initially tapped image participates in the Hero
              if (index == widget.initialIndex) {
                return Center(
                  child: Hero(
                    tag: widget.heroTag,
                    child: image,
                  ),
                );
              } else {
                return Center(child: image);
              }
            },
          ),

          // --------- left/right arrows ----------
          if (total > 1) ...[
            Positioned(
              left: 12,
              child: IconButton(
                iconSize: 32,
                splashRadius: 24,
                color: Colors.white.withOpacity(_current > 0 ? 0.9 : 0.3),
                onPressed: _current > 0 ? () => _goTo(_current - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ),
            Positioned(
              right: 12,
              child: IconButton(
                iconSize: 32,
                splashRadius: 24,
                color: Colors.white
                    .withOpacity(_current < total - 1 ? 0.9 : 0.3),
                onPressed: _current < total - 1
                    ? () => _goTo(_current + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          ],

          // --------- page indicator (1 / N + dots) ----------
          if (total > 1)
            Positioned(
              bottom: 24,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_current + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      total,
                      (i) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _current
                              ? Colors.white
                              : Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
