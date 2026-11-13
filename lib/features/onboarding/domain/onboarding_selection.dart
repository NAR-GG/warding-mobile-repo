/// 비회원 온보딩 선택값(리그·팀·선수). 로그인 시 `POST /api/auth/onboarding`
/// 으로 1회 동기화하기 위한 로컬 저장 페이로드다.
class OnboardingSelection {
  const OnboardingSelection({
    this.leagueName,
    required this.teamId,
    this.playerIds = const [],
  });

  /// 선호 리그 이름. 예: 'LCK'. 선택 안 했으면 null.
  final String? leagueName;

  /// 선호 팀 ID.
  final int teamId;

  /// 선호 선수 ID 목록.
  final List<int> playerIds;

  Map<String, dynamic> toJson() => {
        'leagueName': leagueName,
        'teamId': teamId,
        'playerIds': playerIds,
      };

  factory OnboardingSelection.fromJson(Map<String, dynamic> json) {
    return OnboardingSelection(
      leagueName: json['leagueName'] as String?,
      teamId: json['teamId'] as int,
      playerIds: ((json['playerIds'] as List<dynamic>?) ?? const [])
          .map((e) => e as int)
          .toList(),
    );
  }
}
