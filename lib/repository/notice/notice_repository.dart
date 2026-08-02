import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../model/notice.dart';
import '../auth/auth_service.dart';

/// 공지사항 API (`/api/notices`). 공개 API라 인증이 필수는 아니지만,
/// ADMIN 계정 토큰을 실어 보내면 임시저장 공지도 내려온다 (앱 검수용).
class NoticeRepository {
  NoticeRepository._();
  static final NoticeRepository instance = NoticeRepository._();

  static const bool useMock = false;

  /// 로그인 상태면 토큰 헤더를 만든다. 만료 토큰이어도 서버가 비회원 취급할 뿐이라
  /// 갱신 시도는 하지 않는다 (ADMIN 검수 용도 한정).
  Future<Map<String, String>?> _optionalAuthHeaders() async {
    final jwt = await AuthService.instance.jwt;
    return jwt == null ? null : {'Authorization': 'Bearer $jwt'};
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

  /// 캘린더 상단 띠배너 대상 공지 목록 (최신 발행순, 최대 5건).
  /// 앱은 이 중 ✕로 닫지 않은 첫 건을 띄운다. 없으면 빈 목록.
  Future<List<Notice>> fetchPromoted() async {
    if (useMock) return [_mockNotices.first];
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
