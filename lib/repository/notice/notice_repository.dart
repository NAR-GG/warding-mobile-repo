import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/notice.dart';
import '../auth/auth_service.dart';
import '../../config/secure_storage.dart';

/// 공지사항 API (`/api/notices`). 공개 API라 인증이 필수는 아니지만,
/// ADMIN 계정 토큰을 실어 보내면 임시저장 공지도 내려온다 (앱 검수용).
class NoticeRepository {
  NoticeRepository._();
  static final NoticeRepository instance = NoticeRepository._();

  static const bool useMock = false;

  /// 로그인 상태면 토큰 헤더를 만든다. 만료 토큰이어도 서버가 비회원 취급할 뿐이라
  /// 갱신 시도는 하지 않는다 (ADMIN 검수 용도 한정).
  Future<Map<String, String>?> _optionalAuthHeaders() async {
    try {
      final jwt = await AuthService.instance.jwt;
      return jwt == null ? null : {'Authorization': 'Bearer $jwt'};
    } on SecureStorageUnavailableException {
      // 토큰을 못 읽으면 비회원으로 조회한다 — 공지는 비회원도 볼 수 있다.
      return null;
    }
  }

  /// 공지 목록을 조회한다 (발행분만, 고정 먼저, 최신순).
  /// ADMIN 토큰이면 임시저장 포함.
  Future<NoticePage> fetchNotices({int page = 0, int size = 20}) async {
    if (useMock) return _mockPage(page);
    final response = await http.get(
      Uri.parse(ApiConfig.noticesUrl(page: page, size: size)),
      headers: await _optionalAuthHeaders(),
    );
    debugPrint('[Notice] 목록 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('공지 조회 실패 (${response.statusCode})');
    }
    return NoticePage.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  /// 공지 조회수 +1. 화면 표시와 무관한 집계라 실패해도 조용히 무시한다
  /// (열람 자체는 이미 성공한 상태 — 에러를 띄울 이유가 없다).
  Future<void> markViewed(int id) async {
    if (useMock) return;
    try {
      final response = await http.post(Uri.parse(ApiConfig.noticeViewUrl(id)));
      debugPrint('[Notice] 조회수 $id ← ${response.statusCode}');
    } catch (e) {
      debugPrint('[Notice] 조회수 $id 실패: $e');
    }
  }

  /// 방금 받은 배너 공지 응답. [_promotedCacheTtl] 동안만 유효하다.
  (DateTime, List<Notice>)? _promotedCache;

  /// 진행 중인 배너 공지 요청. 같은 조회가 겹치면 여기에 합류한다.
  Future<List<Notice>>? _promotedInFlight;

  /// 배너 공지 캐시를 신뢰하는 시간.
  ///
  /// 스플래시에서 미리 받은 응답을 곧이어 열리는 일정 화면이 재사용하는 게
  /// 목적이다. 배너가 캘린더보다 늦게 도착하면 그 순간 목록 위에 끼어들어
  /// 캘린더를 통째로 밀어내므로(레이아웃 이동), 화면이 뜨기 전에 유무가
  /// 확정돼 있어야 한다. 공지는 스코어처럼 시시각각 바뀌지 않아 캘린더보다
  /// 길게 잡아도 되지만, 새 공지가 늦게 보이지 않도록 분 단위로 끊는다.
  static const Duration _promotedCacheTtl = Duration(minutes: 5);

  /// 배너 공지 요청 한 건이 살아 있을 수 있는 최대 시간.
  ///
  /// 백그라운드에 들어가면 OS 가 프로세스를 멈춰 소켓 타임아웃도 같이 얼어붙는다.
  /// 상한이 없으면 그 요청이 영원히 진행 중으로 남아, 뒤따르는 조회가 계속
  /// 거기에 합류한다.
  static const Duration _promotedTimeout = Duration(seconds: 10);

  /// 유효한 캐시가 있으면 그 배너 공지 목록, 없으면 null.
  ///
  /// [ScheduleViewModel] 이 **첫 프레임을 그리기 전에** 배너 유무를 정하는 데
  /// 쓴다. 같은 값을 [fetchPromoted] 로 받으면 아무리 빨라도 한 프레임 뒤라,
  /// 그 사이에 배너 없는 화면이 한 번 그려졌다가 배너가 끼어들며 캘린더를
  /// 밀어낸다 — 스플래시에서 미리 받아 둔 보람이 사라진다.
  List<Notice>? get cachedPromoted {
    final cached = _promotedCache;
    if (cached == null) return null;
    if (DateTime.now().difference(cached.$1) >= _promotedCacheTtl) return null;
    return cached.$2;
  }

  /// 캘린더 상단 띠배너 대상 공지 목록 (최신 발행순, 최대 5건).
  /// 앱은 이 중 ✕로 닫지 않은 첫 건을 띄운다. 없으면 빈 목록.
  ///
  /// 같은 조회가 이미 떠 있거나 방금 끝났으면 그 결과를 재사용한다.
  /// [forceRefresh] 를 주면 캐시를 건너뛰고 새로 받는다.
  Future<List<Notice>> fetchPromoted({bool forceRefresh = false}) {
    if (useMock) return Future.value([_mockNotices.first]);

    if (!forceRefresh) {
      final cached = _promotedCache;
      if (cached != null &&
          DateTime.now().difference(cached.$1) < _promotedCacheTtl) {
        debugPrint('[Notice] 배너 cache hit');
        return Future.value(cached.$2);
      }
      final inFlight = _promotedInFlight;
      if (inFlight != null) {
        debugPrint('[Notice] 배너 요청 합류');
        return inFlight;
      }
    }

    final request = _fetchPromoted().timeout(_promotedTimeout).then((notices) {
      _promotedCache = (DateTime.now(), notices);
      return notices;
    });
    // 성공·실패 무관하게 진행 중 표시를 지운다. 실패한 요청이 남아 있으면
    // 다음 조회가 이미 끝난 실패 future 에 합류해 계속 같은 에러만 받는다.
    // 그 사이 새 요청이 들어와 있으면 그 쪽을 지우지 않도록 확인한다.
    // 정리용 체인 자체의 에러는 여기서 삼킨다 — 원본 에러는 호출자가 받는다.
    unawaited(request.whenComplete(() {
      if (identical(_promotedInFlight, request)) _promotedInFlight = null;
    }).catchError((_) => const <Notice>[]));
    _promotedInFlight = request;
    return request;
  }

  Future<List<Notice>> _fetchPromoted() async {
    final response = await http.get(Uri.parse(ApiConfig.promotedNoticeUrl));
    debugPrint('[Notice] 배너 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('배너 공지 조회 실패 (${response.statusCode})');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    return [
      for (final item in body) Notice.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// 테스트 전용 — 캐시를 비워 다음 [fetchPromoted] 가 다시 네트워크를 보게 한다.
  /// `instance` 는 테스트 파일 전체가 공유하는 싱글턴이라, 응답을 갈아끼우는
  /// 테스트는 `setUp` 에서 이걸 불러야 이전 테스트 값이 남지 않는다.
  @visibleForTesting
  void resetPromotedCacheForTesting() {
    _promotedCache = null;
    _promotedInFlight = null;
  }

  // ── mock ─────────────────────────────────────────────────────────

  NoticePage _mockPage(int page) =>
      NoticePage(notices: page == 0 ? _mockNotices : const [], last: true);

  static final List<Notice> _mockNotices = [
    Notice(
      id: 3,
      title: '[업데이트] 워딩 1.0.5 업데이트 안내',
      content: '안녕하세요, 워딩입니다. 워딩 1.0.5 업데이트가 배포되었습니다.\n\n'
          '## 개선 사항\n'
          '- 선수 평점 집계가 더 정확해졌어요.\n'
          '- 경기 일정 알림 오류가 수정되었어요.\n\n'
          '스토어에서 업데이트 후 이용해 주세요.',
      pinned: true,
      publishedAt: DateTime(2026, 7, 28, 10),
    ),
    Notice(
      id: 2,
      title: '[반영완료] 선수 추가 요청 반영 완료 안내 (7월 4주차)',
      content: '안녕하세요, 워딩입니다. 이번 주에 접수해 주신 선수 추가 요청이 반영되었습니다.\n\n'
          '## 추가된 선수\n'
          "- DK '루시드' 최용혁 — 정글\n"
          "- KT '커즈' 문우찬 — 정글\n\n"
          '## 참고\n'
          '- 선수 검색과 구독은 앱 재실행 후 바로 가능합니다.\n'
          '- 추가 요청은 마이페이지 → 문의하기로 보내주세요.',
      pinned: false,
      publishedAt: DateTime(2026, 7, 29, 14, 20),
    ),
    Notice(
      id: 1,
      title: 'LCK 서머 플레이오프 일정 반영 안내',
      content: 'LCK 서머 플레이오프 일정이 캘린더에 반영되었습니다.\n\n'
          '경기 일정 탭에서 확인해 주세요.',
      pinned: false,
      publishedAt: DateTime(2026, 7, 27, 9),
    ),
  ];
}
