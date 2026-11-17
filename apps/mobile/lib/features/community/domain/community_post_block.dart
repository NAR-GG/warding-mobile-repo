import 'dart:convert';

/// 블록 본문(bodyFormat=BLOCKS)의 블록 하나. 서버 계약(handoff 문서 "블록 본문" 절):
///
/// ```json
/// [{"type":"text","text":"...","style":"body|heading"},
///  {"type":"image","url":"..."},
///  {"type":"link","url":"...","title":"...","description":"...","imageUrl":"...","siteName":"..."},
///  {"type":"embed","provider":"youtube|chzzk|soop|x","url":"..."}]
/// ```
class CommunityPostBlock {
  const CommunityPostBlock({
    required this.type,
    this.text,
    this.style,
    this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.provider,
  });

  final String type;
  final String? text;

  /// text 블록만: body | heading. 서버 기본값이 body 라 null 이면 body 로 그린다.
  final String? style;
  final String? url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  /// embed 블록만: youtube | chzzk | soop | x.
  final String? provider;

  bool get isHeading => style == 'heading';

  factory CommunityPostBlock.fromJson(Map<String, dynamic> json) {
    return CommunityPostBlock(
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      style: json['style'] as String?,
      url: json['url'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      siteName: json['siteName'] as String?,
      provider: json['provider'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (text != null) 'text': text,
    if (style != null) 'style': style,
    if (url != null) 'url': url,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (siteName != null) 'siteName': siteName,
    if (provider != null) 'provider': provider,
  };

  /// 상세 body(블록 JSON 문자열) → 블록 목록. 파싱 실패는 빈 목록 — 렌더러가
  /// 평문 폴백으로 그리게 한다(서버가 검증해 내려주므로 실제로는 안 일어난다).
  static List<CommunityPostBlock> parseList(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map<String, dynamic>) CommunityPostBlock.fromJson(e),
      ];
    } on FormatException {
      return const [];
    }
  }

  static String encodeList(List<CommunityPostBlock> blocks) =>
      jsonEncode([for (final b in blocks) b.toJson()]);

  /// URL 이 임베드 제공자면 그 provider, 아니면 null(일반 링크 카드).
  /// 서버 화이트리스트(handoff 문서)와 같은 목록이다.
  static String? embedProviderOf(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase();
    if (host == null || host.isEmpty) return null;
    bool matches(String domain) => host == domain || host.endsWith('.$domain');
    if (matches('youtube.com') || matches('youtu.be')) return 'youtube';
    if (matches('chzzk.naver.com')) return 'chzzk';
    if (matches('sooplive.co.kr') || matches('afreecatv.com')) return 'soop';
    if (matches('x.com') || matches('twitter.com')) return 'x';
    return null;
  }

  /// 유튜브 URL 의 영상 id(썸네일용). 못 찾으면 null.
  static String? youtubeVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (host.contains('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      // /shorts/{id}, /embed/{id}, /live/{id}
      final segs = uri.pathSegments;
      if (segs.length >= 2 &&
          const {'shorts', 'embed', 'live'}.contains(segs[0])) {
        return segs[1];
      }
    }
    return null;
  }
}

/// `GET /community/link-preview` 응답 — OG 스냅샷. 실패 시 title 이하 null.
class CommunityLinkPreview {
  const CommunityLinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  factory CommunityLinkPreview.fromJson(Map<String, dynamic> json) {
    return CommunityLinkPreview(
      url: json['url'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      siteName: json['siteName'] as String?,
    );
  }
}
