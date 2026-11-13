/// 온보딩에서 선택하는 LCK 등 리그 소속 팀.
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.code,
    required this.imageUrl,
  });

  /// 팀 고유 ID.
  final int id;

  /// 팀 이름. 예: 'T1'.
  final String name;

  /// 팀 코드(약자). 예: 'T1'.
  final String code;

  /// 팀 로고 이미지 URL.
  final String imageUrl;

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      code: (json['code'] ?? '') as String,
      imageUrl: (json['imageUrl'] ?? '') as String,
    );
  }

  /// JSON 직렬화 — 선호 팀 로컬 저장 등에 쓴다.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'imageUrl': imageUrl,
  };
}
