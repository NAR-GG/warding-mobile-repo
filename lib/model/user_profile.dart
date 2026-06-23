/// 로그인 회원의 기본 정보.
///
/// `GET /api/auth/me` · `PUT /api/auth/me` 응답에 대응한다.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    this.name = '',
    this.tag = '',
    this.email,
    this.favoriteLeagueName,
    this.favoriteTeamId,
    this.favoritePlayerIds = const [],
    this.profileImageUrl,
    this.isOnboarded = false,
  });

  final int id;

  /// 표시용 합쳐진 닉네임. 예: '짱아깨비#KR2'.
  final String nickname;

  /// 닉네임의 이름 부분. 예: '짱아깨비'.
  final String name;

  /// 닉네임의 태그 부분(영숫자 2~5자). 예: 'KR2'.
  final String tag;

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
    final nickname = json['nickname'] as String? ?? '';
    // name·tag 가 응답에 없으면 nickname('name#tag')에서 분리한다(방어).
    final sep = nickname.indexOf('#');
    final fallbackName = sep >= 0 ? nickname.substring(0, sep) : nickname;
    final fallbackTag = sep >= 0 ? nickname.substring(sep + 1) : '';
    return UserProfile(
      id: json['id'] as int? ?? 0,
      nickname: nickname,
      name: json['name'] as String? ?? fallbackName,
      tag: json['tag'] as String? ?? fallbackTag,
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
