import 'package:flutter/widgets.dart';

class InlineYoutubePlayer extends StatelessWidget {
  const InlineYoutubePlayer({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
