/// 글에 붙는 투표(글당 1개, 단일 선택, 변경 불가).
///
/// [resultsVisible] 이 false(미투표 + 숨김 설정)면 서버가 [CommunityPollOption.voteCount]
/// 를 null 로 잘라 보낸다 — 분포 은닉은 서버 책임이라 앱은 그대로 그리면 된다.
class CommunityPoll {
  const CommunityPoll({
    required this.id,
    required this.question,
    required this.totalVotes,
    required this.resultsVisible,
    this.allowMultiple = false,
    this.closesAt,
    this.closed = false,
    this.myOptionIds = const {},
    required this.options,
  });

  final int id;
  final String question;

  /// 참여 인원(사람 기준, 항상 공개). 퍼센트 분모 — 복수 선택은 합이 100%를 넘을 수 있다.
  final int totalVotes;

  /// 분포(선택지별 표 수)를 보여줄 수 있는가 — 투표함·공개 설정·마감 중 하나.
  final bool resultsVisible;

  /// 복수 선택 허용 — 선택지마다 한 표씩 더 던질 수 있다.
  final bool allowMultiple;

  /// 마감 시각. null = 마감 없음.
  final DateTime? closesAt;

  /// 마감됨(서버 판정) — true 면 투표 불가.
  final bool closed;

  /// 내가 고른 선택지들. 비로그인·미투표면 빈 집합.
  final Set<int> myOptionIds;

  final List<CommunityPollOption> options;

  bool get voted => myOptionIds.isNotEmpty;

  factory CommunityPoll.fromJson(Map<String, dynamic> json) {
    return CommunityPoll(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
      resultsVisible: json['resultsVisible'] as bool? ?? false,
      allowMultiple: json['allowMultiple'] as bool? ?? false,
      closesAt: DateTime.tryParse(json['closesAt'] as String? ?? ''),
      closed: json['closed'] as bool? ?? false,
      myOptionIds: {
        for (final id in json['myOptionIds'] as List<dynamic>? ?? const [])
          (id as num).toInt(),
      },
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((e) => CommunityPollOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CommunityPollOption {
  const CommunityPollOption({
    required this.id,
    required this.label,
    this.voteCount,
  });

  final int id;
  final String label;

  /// 결과 비공개 상태면 null.
  final int? voteCount;

  factory CommunityPollOption.fromJson(Map<String, dynamic> json) {
    return CommunityPollOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      voteCount: (json['voteCount'] as num?)?.toInt(),
    );
  }
}
