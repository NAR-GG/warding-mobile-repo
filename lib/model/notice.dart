/// 공지사항 한 건.
///
/// `GET /api/notices` 응답 항목에 대응한다. 작성자는 항상 "관리자"로
/// 노출하므로 별도 필드가 없고, 구분이 필요한 공지는 제목 말머리
/// (`[업데이트]` 등)로 표현한다.
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.pinned,
    this.publishedAt,
  });

  final int id;
  final String title;

  /// 마크다운 본문 (## 제목, - 리스트 수준의 단순 문법).
  final String content;

  /// 목록 최상단 고정 여부.
  final bool pinned;

  /// 발행 시각. null 이면 임시저장 — ADMIN 계정으로 조회할 때만 내려온다.
  final DateTime? publishedAt;

  bool get isDraft => publishedAt == null;

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        pinned: json['pinned'] as bool? ?? false,
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      );
}

/// 공지사항 페이지 응답 (Spring Pageable).
class NoticePage {
  const NoticePage({required this.notices, required this.last});

  final List<Notice> notices;

  /// 마지막 페이지 여부.
  final bool last;

  factory NoticePage.fromJson(Map<String, dynamic> json) => NoticePage(
        notices: [
          for (final item in (json['content'] as List? ?? const []))
            Notice.fromJson(item as Map<String, dynamic>),
        ],
        last: json['last'] as bool? ?? true,
      );
}
