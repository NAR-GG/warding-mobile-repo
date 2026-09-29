import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// 쇼츠 한 편을 그리는 임베드. 테스트가 WebView 없이 갈아끼울 수 있게
/// [ShortsEmbedBuilder] 로 주입한다.
typedef ShortsEmbedBuilder =
    Widget Function(
      BuildContext context, {
      required String videoId,
      required bool active,
      required VoidCallback onPlaying,
      required VoidCallback onEnded,
      required void Function(Object code) onError,
    });

/// 유튜브 공식 IFrame 임베드(WebView). 소리는 항상 끈 채로 재생하고,
/// [active] 인 동안만 재생한다.
Widget youtubeShortsEmbed(
  BuildContext context, {
  required String videoId,
  required bool active,
  required VoidCallback onPlaying,
  required VoidCallback onEnded,
  required void Function(Object code) onError,
}) => _YoutubeShortsEmbed(
  key: ValueKey(videoId),
  videoId: videoId,
  active: active,
  onPlaying: onPlaying,
  onEnded: onEnded,
  onError: onError,
);

class _YoutubeShortsEmbed extends StatefulWidget {
  const _YoutubeShortsEmbed({
    super.key,
    required this.videoId,
    required this.active,
    required this.onPlaying,
    required this.onEnded,
    required this.onError,
  });

  final String videoId;
  final bool active;
  final VoidCallback onPlaying;
  final VoidCallback onEnded;
  final void Function(Object code) onError;

  @override
  State<_YoutubeShortsEmbed> createState() => _YoutubeShortsEmbedState();
}

class _YoutubeShortsEmbedState extends State<_YoutubeShortsEmbed> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  PlayerState? _lastState;
  bool _errorReported = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: widget.active,
      params: const YoutubePlayerParams(
        mute: true,
        showControls: true,
        showFullscreenButton: false,
        playsInline: true,
      ),
    );
    _sub = _controller.stream.listen(_onValue);
  }

  void _onValue(YoutubePlayerValue v) {
    if (v.error != YoutubeError.none && !_errorReported) {
      _errorReported = true;
      widget.onError(v.error.code);
      return;
    }
    if (v.playerState == _lastState) return;
    _lastState = v.playerState;
    if (!widget.active) return;
    if (v.playerState == PlayerState.playing) widget.onPlaying();
    if (v.playerState == PlayerState.ended) widget.onEnded();
  }

  @override
  void didUpdateWidget(_YoutubeShortsEmbed old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    if (widget.active) {
      // 미리 로드만 해 둔(cue) 플레이어는 playVideo 만으로 시작하지 않는 경우가
      // 있어, 다시 로드하면서 재생한다.
      _controller.loadVideoById(videoId: widget.videoId);
    } else {
      _controller.pauseVideo();
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => YoutubePlayer(controller: _controller);
}
