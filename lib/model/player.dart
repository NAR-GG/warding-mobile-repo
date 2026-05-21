/// 온보딩에서 선택하는 e스포츠 선수.
///
/// 온보딩 완료 시 [id] 가 `favoritePlayerIds` 로 서버에 전송된다.
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.role,
  });

  /// 선수 고유 ID.
  final int id;

  /// 선수 이름(닉네임). 예: 'Faker'.
  final String name;

  /// 선수 이미지 URL.
  final String imageUrl;

  /// 포지션. 예: 'mid'.
  final String role;

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      imageUrl: (json['imageUrl'] ?? '') as String,
      role: (json['role'] ?? '') as String,
    );
  }
}
