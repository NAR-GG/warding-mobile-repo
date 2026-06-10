/// 로그인 회원의 기본 정보.
///
/// `GET /api/auth/me` 응답에 대응한다.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    this.favoriteLeagueName,
    this.favoriteTeamId,
    this.favoritePlayerIds = const [],
    this.isOnboarded = false,
  });

  final int id;
  final String nickname;

  /// 응원 리그 이름. 예: 'LCK'.
  final String? favoriteLeagueName;

  /// 응원 팀 ID. 없을 수 있다.
  final int? favoriteTeamId;

  /// 선호 선수 ID 목록.
  final List<int> favoritePlayerIds;

  final bool isOnboarded;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 0,
      nickname: json['nickname'] as String? ?? '',
      favoriteLeagueName: json['favoriteLeagueName'] as String?,
      favoriteTeamId: json['favoriteTeamId'] as int?,
      favoritePlayerIds: (json['favoritePlayerIds'] as List<dynamic>? ?? const [])
          .map((e) => e as int)
          .toList(),
      isOnboarded: json['isOnboarded'] as bool? ?? false,
    );
  }
}
