import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) async {
    final normalized = imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      return;
    }

    final safeIndex = initialIndex.clamp(0, normalized.length - 1);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenImageViewer(
          imageUrls: normalized,
          initialIndex: safeIndex,
        ),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _pageController;
  late final FocusNode _keyboardFocusNode;
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _keyboardFocusNode = FocusNode(debugLabel: 'fullscreen-image-viewer');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _keyboardFocusNode.requestFocus();
    });
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) {
      return;
    }

    final safeIndex = index.clamp(0, widget.imageUrls.length - 1);
    if (safeIndex == _activeIndex) {
      return;
    }

    _pageController.animateToPage(
      safeIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      _goToPage(_activeIndex + 1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      _goToPage(_activeIndex - 1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Focus(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Listener(
            onPointerDown: (_) {
              _keyboardFocusNode.requestFocus();
            },
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (index) {
                    setState(() => _activeIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final imageUrl = widget.imageUrls[index];
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text(
                                'Không thể tải ảnh',
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_activeIndex + 1}/${widget.imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
