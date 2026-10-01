import 'dart:async';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
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

/// 유튜브 공식 IFrame 임베드(WebView). 처음 재생을 시작할 때만 무음으로
/// 켜고(자동재생 정책), 그 뒤로는 `showControls: true`로 노출되는 유튜브
/// 기본 컨트롤바의 음소거 버튼으로 소리를 켜고 끌 수 있다 — 같은 영상으로
/// 되돌아와도(다시 active) 그 음소거 상태를 건드리지 않는다. [active] 인
/// 동안만 재생한다.
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

  /// 이 컨트롤러로 영상을 이미 한 번 로드했는지. 로드한 적이 있으면 다시
  /// active 가 돼도 [YoutubePlayerController.loadVideoById] 를 또 부르지
  /// 않는다 — loadVideoById 는 플레이어를 처음 상태(무음)로 되돌려서,
  /// 유저가 유튜브 기본 컨트롤로 켠 소리가 페이지를 벗어났다 돌아올 때마다
  /// 꺼지게 만든다.
  bool _loaded = false;

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
    _loaded = widget.active;
    _sub = _controller.stream.listen(_onValue);
  }

  void _onValue(YoutubePlayerValue v) {
    if (v.error != YoutubeError.none && !_errorReported) {
      _reportError(v.error.code);
      return;
    }
    if (v.playerState == _lastState) return;
    _lastState = v.playerState;
    if (!widget.active) return;
    if (v.playerState == PlayerState.playing) widget.onPlaying();
    if (v.playerState == PlayerState.ended) widget.onEnded();
  }

  // WebView 쪽 IFrame API 가 끝내 ready 이벤트를 못 쏴 주면(네트워크 문제 등)
  // 패키지가 30초 뒤 TimeoutException 을 던진다 — 잡아서 기존 오류 폴백으로 보낸다.
  void _reportError(Object code) {
    if (_errorReported || !mounted) return;
    _errorReported = true;
    widget.onError(code);
  }

  @override
  void didUpdateWidget(_YoutubeShortsEmbed old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    if (widget.active) {
      if (_loaded) {
        // 이미 로드했던 영상으로 되돌아온 것 — 다시 로드하면 유튜브 기본
        // 컨트롤로 켠 소리가 꺼지므로 재생만 재개한다.
        unawaited(_controller.playVideo().catchError((Object e) {
          _reportError(e);
        }));
      } else {
        // 미리 로드만 해 둔(cue) 플레이어는 playVideo 만으로 시작하지 않는
        // 경우가 있어, 처음 한 번은 로드하면서 재생한다.
        _loaded = true;
        unawaited(
          _controller
              .loadVideoById(videoId: widget.videoId)
              .catchError((Object e) => _reportError(e)),
        );
      }
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
  Widget build(BuildContext context) => YoutubePlayer(
    controller: _controller,
    // 이 화면은 이미 그 자체로 전체화면 세로 피드라 패키지의 "전체화면"
    // 기능이 필요 없다. 기본값(둘 다 true)을 켜 두면 두 가지 문제가 있었다:
    // (1) 플레이어 위 세로 드래그를 "전체화면 진입" 제스처로 가로채서,
    //     다음 영상으로 넘기려는 PageView 세로 스와이프가 영상 위에서는
    //     먹지 않았다.
    // (2) 전체화면 상태에서는 패키지의 PopScope가 시스템 뒤로가기·X 버튼의
    //     pop을 "전체화면 탈출"로만 소비해, 화면을 아예 닫을 수 없었다.
    enableFullScreenOnVerticalDrag: false,
    autoFullScreen: false,
    // 패키지 기본값은 "세로·가로 제스처를 플레이어(WebView)가 흡수"하는
    // 것이라, 위 두 플래그를 꺼도 네이티브 WebView가 포인터 이벤트를 먼저
    // 가져가 버려 부모 PageView가 세로 스와이프를 전혀 못 받았다.
    // VerticalDragGestureRecognizer를 명시적으로 등록해 제스처 아레나에서
    // Flutter 쪽(PageView)과 정상적으로 경쟁하게 한다.
    gestureRecognizers: {
      Factory<VerticalDragGestureRecognizer>(VerticalDragGestureRecognizer.new),
    },
  );
}
