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

  /// 로컬 저장값 복원 — 앱이 [toJson] 으로 직접 쓴 형식만 읽는다.
  ///
  /// **서버 응답은 이걸로 파싱하지 않는다.** 그쪽은
  /// `features/onboarding/data/models/team_dto.dart` + 매퍼를 거친다 — 서버가
  /// 필드명을 바꿀 때 Entity 를 고치지 않으려는 것이다. 로컬 형식은 앱이
  /// 정하므로 여기 둬도 외부 변경에 노출되지 않는다.
  factory Team.fromStorage(Map<String, dynamic> json) => Team(
    id: json['id'] as int,
    name: (json['name'] ?? '') as String,
    code: (json['code'] ?? '') as String,
    imageUrl: (json['imageUrl'] ?? '') as String,
  );

  /// 로컬 저장용 직렬화. [fromStorage] 와 짝이다.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'imageUrl': imageUrl,
  };
}
