/// 팀 한 건의 서버 응답 DTO (`GET /api/teams`).
///
/// 변환은 `data/mappers/team_mapper.dart` 가 한다.
class TeamDto {
  const TeamDto({
    required this.id,
    required this.name,
    required this.code,
    required this.imageUrl,
  });

  final int id;
  final String name;
  final String code;
  final String imageUrl;

  factory TeamDto.fromJson(Map<String, dynamic> json) => TeamDto(
    id: json['id'] as int,
    name: (json['name'] ?? '') as String,
    code: (json['code'] ?? '') as String,
    imageUrl: (json['imageUrl'] ?? '') as String,
  );
}
