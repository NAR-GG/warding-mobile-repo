import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:warding/core/di_container.dart';
import 'package:warding/features/shorts/domain/entities/story_video.dart';
import 'package:warding/features/shorts/domain/repositories/shorts_repository.dart';

/// 쇼츠 요약 카드의 필터.
enum ShortsSummaryFilter { all, team }

/// 다른 화면에 끼워 넣는 쇼츠 요약 카드 목록의 상태.
///
/// 전체화면 피드는 [ShortsFeedViewModel] 이다 — 그쪽은 페이지 인덱스·프리페치·
/// 재생 상태·연속 에러 스킵을 다루고, 이쪽은 카드 [cardCount] 개만 받는다.
/// 피드는 이 VM 이 받아 둔 목록을 `initialVideos` 로 이어받아 시작한다.
///
/// **응원팀을 콜백으로 받는다.** "내 팀" 필터가 응원팀에 달려 있는데, 그
/// 결정 규칙(서버 우선·로컬 폴백)은 이 기능 소유가 아니다 — 쓰는 쪽이 넘긴다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다.
class ShortsSummaryViewModel extends ChangeNotifier {
  ShortsSummaryViewModel({
    required Future<String?> Function() resolveTeamCode,
    ShortsRepository? repository,
    this.cardCount = 10,
  }) : _resolveTeamCode = resolveTeamCode,
       _repository = repository ?? di<ShortsRepository>();

  final ShortsRepository _repository;

  /// 응원팀 코드를 돌려준다. null 이면 미설정 — 화면이 설정 안내를 보인다.
  final Future<String?> Function() _resolveTeamCode;

  /// 보여줄 카드 수.
  final int cardCount;

  /// 응원팀 필터는 서버가 아직 팀을 안 거르는 동안에도 카드가 [cardCount] 개
  /// 남도록 넉넉히 받아 클라이언트에서 거른다.
  static const int teamFetchSize = 30;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  ShortsSummaryFilter _filter = ShortsSummaryFilter.all;
  ShortsSummaryFilter get filter => _filter;

  /// "내 팀" 필터로 바꾼 직후 응원팀·영상 목록을 다시 받는 동안 true.
  /// 이 플래그가 없으면 필터를 바꾼 첫 프레임에 이전(전체) 목록을 새 필터로
  /// 걸러 빈 리스트가 되고, 아직 응원팀 조회 전이라 "응원팀 미설정" 안내가
  /// 한 프레임 잘못 떴다가 실제 결과로 바뀌는 깜빡임이 있었다.
  bool _loading = false;
  bool get loading => _loading;

  void setFilter(ShortsSummaryFilter value) {
    if (value == _filter) return;
    _filter = value;
    _loading = true;
    notifyListeners();
    unawaited(load());
  }

  /// 마지막으로 확인한 응원팀 코드. null 이면 없거나 아직 모른다.
  String? _teamCode;

  /// "내 팀" 필터에 쓸 응원팀이 있는지. 없으면 화면이 설정 안내를 보인다.
  bool get hasTeam => _teamCode != null;

  List<StoryVideo> _videos = const [];

  int _gen = 0;

  Future<void> load() async {
    final gen = ++_gen;
    try {
      final onlyTeam = _filter == ShortsSummaryFilter.team;
      if (onlyTeam) {
        _teamCode = await _resolveTeamCode();
        if (_disposed || gen != _gen) return;
        if (_teamCode == null) {
          _videos = const [];
          _loading = false;
          notifyListeners();
          return;
        }
      }
      final result = await _repository.fetchShortsPage(
        sort: 'latest',
        size: onlyTeam ? teamFetchSize : cardCount,
        teamCode: onlyTeam ? _teamCode : null,
      );
      if (_disposed || gen != _gen) return;
      // 실패하면 빈 목록으로 둔다 — 한 섹션이고 다른 섹션은 영향이 없다.
      _videos = result
          .getOrElse((_) => const ShortsPage(items: [], isLast: true))
          .items;
      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[ShortsSummary] 쇼츠 조회 실패: $e');
      if (_disposed || gen != _gen) return;
      _loading = false;
      notifyListeners();
    }
  }

  /// 현재 필터를 적용한 영상 — 순수 최신순(서버 순서) 최대 [cardCount] 개.
  ///
  /// "내 팀"은 응원팀 채널의 쇼츠만이다. 응답의 `teamCode` 로 한 번 더 거르니
  /// LCK 공식 채널(팀 코드 없음)은 "전체"에만 나온다.
  List<StoryVideo> get videos {
    final team = _teamCode;
    final source = _filter == ShortsSummaryFilter.team
        ? _videos.where((v) => team != null && v.teamCode == team)
        : _videos;
    return source.take(cardCount).toList();
  }

  /// 마지막으로 받은 목록의 페이지 크기 — 피드가 다음 페이지부터 같은 크기로
  /// 이어 받는다.
  int get fetchSize =>
      _filter == ShortsSummaryFilter.team ? teamFetchSize : cardCount;

  /// 응원팀 코드를 확인해 돌려준다. 피드가 "내 팀" 필터를 고를 때 쓴다.
  Future<String?> teamCode() async {
    _teamCode = await _resolveTeamCode();
    return _teamCode;
  }
}
