import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/theme/wolf_colors.dart';

class TrailerPlayerScreen extends StatefulWidget {
  const TrailerPlayerScreen({
    super.key,
    required this.title,
    this.youtubeKey,
  });

  final String title;
  final String? youtubeKey;

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final key = widget.youtubeKey;
    if (key != null && key.isNotEmpty) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: key,
        autoPlay: true,
        params: const YoutubePlayerParams(
          mute: false,
          enableCaption: true,
          showFullscreenButton: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('No playable trailer key.')),
      );
    }

    return Scaffold(
      backgroundColor: WolfColors.voidBlack,
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          YoutubePlayer(
            controller: controller,
            backgroundColor: WolfColors.voidBlack,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Official trailer playback · WOLFTVEE',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
