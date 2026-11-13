/// 온보딩에서 선택하는 e스포츠 리그. 예: LCK.
///
/// 리그는 별도 ID 없이 [name] 으로 식별한다.
/// 온보딩 완료 시 이 [name] 이 `favoriteLeagueName` 으로 서버에 전송된다.
class League {
  const League({
    required this.name,
    required this.regionName,
    required this.imageUrl,
  });

  /// 리그 이름. 예: 'LCK'.
  final String name;

  /// 리그 지역명. 예: '대한민국'.
  final String regionName;

  /// 리그 로고 이미지 URL.
  final String imageUrl;

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      name: (json['name'] ?? '') as String,
      regionName: (json['regionName'] ?? '') as String,
      imageUrl: (json['imageUrl'] ?? '') as String,
    );
  }
}
