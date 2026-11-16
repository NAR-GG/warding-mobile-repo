import 'package:warding/domain/team.dart';
import 'package:warding/features/onboarding/data/models/team_dto.dart';

/// DTO → Entity 변환. 추상화하지 않는다.
class TeamMapper {
  const TeamMapper._();

  static Team toDomain(TeamDto dto) =>
      Team(id: dto.id, name: dto.name, code: dto.code, imageUrl: dto.imageUrl);

  static List<Team> listToDomain(Iterable<TeamDto> dtos) =>
      dtos.map(toDomain).toList();
}
