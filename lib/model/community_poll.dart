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
    this.myOptionId,
    required this.options,
  });

  final int id;
  final String question;

  /// 참여 인원(항상 공개).
  final int totalVotes;

  /// 분포(선택지별 표 수)를 보여줄 수 있는가.
  final bool resultsVisible;

  /// 내가 고른 선택지. 비로그인·미투표면 null.
  final int? myOptionId;

  final List<CommunityPollOption> options;

  bool get voted => myOptionId != null;

  factory CommunityPoll.fromJson(Map<String, dynamic> json) {
    return CommunityPoll(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
      resultsVisible: json['resultsVisible'] as bool? ?? false,
      myOptionId: (json['myOptionId'] as num?)?.toInt(),
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
