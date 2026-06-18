/// 로그인 회원의 기본 정보.
///
/// `GET /api/auth/me` · `PUT /api/auth/me` 응답에 대응한다.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    this.email,
    this.favoriteLeagueName,
    this.favoriteTeamId,
    this.favoritePlayerIds = const [],
    this.profileImageUrl,
    this.isOnboarded = false,
  });

  final int id;
  final String nickname;

  /// 회원 이메일. 소셜 계정에서 받지 못한 경우 null.
  final String? email;

  /// 응원 리그 이름. 예: 'LCK'.
  final String? favoriteLeagueName;

  /// 응원 팀 ID. 없을 수 있다.
  final int? favoriteTeamId;

  /// 선호 선수 ID 목록.
  final List<int> favoritePlayerIds;

  /// 프로필 이미지 URL. 미설정이면 null.
  final String? profileImageUrl;

  final bool isOnboarded;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 0,
      nickname: json['nickname'] as String? ?? '',
      email: json['email'] as String?,
      favoriteLeagueName: json['favoriteLeagueName'] as String?,
      favoriteTeamId: json['favoriteTeamId'] as int?,
      favoritePlayerIds: (json['favoritePlayerIds'] as List<dynamic>? ?? const [])
          .map((e) => e as int)
          .toList(),
      profileImageUrl: json['profileImageUrl'] as String?,
      isOnboarded: json['isOnboarded'] as bool? ?? false,
    );
  }
}
