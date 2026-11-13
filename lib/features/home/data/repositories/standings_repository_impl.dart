import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/data/failure_mapper.dart';
import 'package:warding/core/error/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/features/home/domain/repositories/standings_repository.dart';
import 'package:warding/features/home/domain/standing.dart';
import 'package:warding/features/home/domain/worlds_standings.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/features/home/data/home_sources.dart' show kHomeMocks;
import 'package:warding/features/home/data/worlds_standings_mock.dart';

/// [StandingsRepository] 의 원격 구현 (`/api/standings`).
class StandingsRepositoryImpl implements StandingsRepository {
  @override
  Future<Either<Failure, StandingsResult>> fetchStandings(
    String league,
  ) async {
    final url = ApiConfig.standingsUrl(league: league);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiStatusException(response.statusCode, endpoint: url);
      }
      return Right(StandingsResult.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      ));
    } catch (e) {
      return Left(toFailure(e, op: 'fetchStandings($league)'));
    }
  }

  @override
  Future<WorldsStandings?> fetchWorldsStandings() async {
    if (!kHomeMocks) return null;
    return worldsStandingsMock;
  }
}
