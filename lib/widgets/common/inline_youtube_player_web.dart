import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class InlineYoutubePlayer extends StatefulWidget {
  const InlineYoutubePlayer({super.key, required this.videoId});

  final String videoId;

  @override
  State<InlineYoutubePlayer> createState() => _InlineYoutubePlayerState();
}

class _InlineYoutubePlayerState extends State<InlineYoutubePlayer> {
  static int _viewTypeSeed = 0;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'inline-youtube-player-${_viewTypeSeed++}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final iframe = html.IFrameElement()
        ..src =
            'https://www.youtube.com/embed/${widget.videoId}?autoplay=1&rel=0&playsinline=1&modestbranding=1'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
