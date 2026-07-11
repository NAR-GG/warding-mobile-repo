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

  /// 포지션 정렬 순서(탑→정글→미드→바텀→서포터). 미상은 맨 뒤.
  static const _roleOrder = {
    'top': 1,
    'jungle': 2,
    'mid': 3,
    'adc': 4,
    'bottom': 4,
    'support': 5,
  };

  int get roleOrder => _roleOrder[role.toLowerCase()] ?? 6;

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      imageUrl: (json['imageUrl'] ?? '') as String,
      role: (json['role'] ?? '') as String,
    );
  }
}
