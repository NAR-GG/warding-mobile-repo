import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/core/data/failure_mapper.dart';
import 'package:warding/core/error/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/features/onboarding/domain/repositories/onboarding_repository.dart';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/features/onboarding/domain/league.dart';
import 'package:warding/features/onboarding/domain/player.dart';
import 'package:warding/domain/team.dart';
import 'package:warding/core/util/sentry_logger.dart';

/// 온보딩 관련 API.
class OnboardingRepositoryImpl implements OnboardingRepository {

  /// 온보딩용 리그 목록 조회. 인증이 필요 없다.
  @override
  Future<Either<Failure, List<League>>> fetchLeagues() async {
    try {
      return Right(await _fetchLeagues());
    } catch (e) {
      return Left(toFailure(e, op: 'fetchLeagues'));
    }
  }

  Future<List<League>> _fetchLeagues() async {
    final response = await http.get(Uri.parse(ApiConfig.onboardingLeaguesUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => League.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 팀 목록 캐시. 마이페이지·경기일정·평점상세·프로필수정이 화면 진입마다
  /// 각자 이 거의 안 바뀌는 목록을 새로 받던 걸 막는다.
  (DateTime, List<Team>)? _teamsCache;
  Future<Either<Failure, List<Team>>>? _teamsInFlight;
  static const Duration _teamsCacheTtl = Duration(minutes: 10);

  /// 온보딩용 LCK 팀 목록 조회. 인증이 필요 없다.
  ///
  /// 같은 요청이 이미 떠 있거나 방금 끝났으면([_teamsCacheTtl] 이내) 그 결과를
  /// 재사용한다.
  @override
  Future<Either<Failure, List<Team>>> fetchTeams() {
    final cached = _teamsCache;
    if (cached != null &&
        DateTime.now().difference(cached.$1) < _teamsCacheTtl) {
      return Future.value(Right(cached.$2));
    }
    final inFlight = _teamsInFlight;
    if (inFlight != null) return inFlight;

    // **성공만 캐시한다.** 실패를 캐시하면 TTL 동안 재시도가 막힌다.
    final request = _fetchTeamsEither().then((result) {
      result.match((_) {}, (teams) {
        _teamsCache = (DateTime.now(), teams);
      });
      return result;
    });
    unawaited(request.whenComplete(() {
      if (identical(_teamsInFlight, request)) _teamsInFlight = null;
    }));
    _teamsInFlight = request;
    return request;
  }

  Future<Either<Failure, List<Team>>> _fetchTeamsEither() async {
    try {
      return Right(await _fetchTeams());
    } catch (e) {
      return Left(toFailure(e, op: 'fetchTeams'));
    }
  }

  Future<List<Team>> _fetchTeams() async {
    final response = await http.get(Uri.parse(ApiConfig.onboardingTeamsUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Team.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 온보딩용 선수 목록 조회. 인증이 필요 없다.
  ///
  /// [teamId] 를 주면 해당 팀 선수만, 안 주면 [year] 시즌 전체 선수를 조회한다.
  @override
  Future<Either<Failure, List<Player>>> fetchPlayers({
    required int year,
    int? teamId,
  }) async {
    try {
      return Right(await _fetchPlayers(year: year, teamId: teamId));
    } catch (e) {
      return Left(toFailure(e, op: 'fetchPlayers'));
    }
  }

  Future<List<Player>> _fetchPlayers({required int year, int? teamId}) async {
    final response = await http.get(
      Uri.parse(ApiConfig.onboardingPlayersUrl(year: year, teamId: teamId)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList()
      // 서버는 이름순으로 주므로 포지션순(탑→정글→미드→바텀→서포터)으로 재정렬. (#97)
      ..sort((a, b) {
        final byRole = a.roleOrder.compareTo(b.roleOrder);
        return byRole != 0 ? byRole : a.name.compareTo(b.name);
      });
  }

  /// 온보딩 완료 — 로그인 사용자의 선호 리그·팀·선수를 서버에 저장한다.
  ///
  /// `POST /api/auth/onboarding` — 인증이 필요하므로 [jwt] 를 헤더에 싣는다.
  @override
  Future<Either<Failure, Unit>> completeOnboarding({
    String? favoriteLeagueName,
    required int favoriteTeamId,
    List<int> favoritePlayerIds = const [],
    required String jwt,
  }) async {
    try {
      await _completeOnboarding(
        favoriteLeagueName: favoriteLeagueName,
        favoriteTeamId: favoriteTeamId,
        favoritePlayerIds: favoritePlayerIds,
        jwt: jwt,
      );
      return const Right(unit);
    } catch (e) {
      return Left(toFailure(e, op: 'completeOnboarding'));
    }
  }

  Future<void> _completeOnboarding({
    String? favoriteLeagueName,
    required int favoriteTeamId,
    List<int> favoritePlayerIds = const [],
    required String jwt,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.onboardingUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({
        'favoriteLeagueName': ?favoriteLeagueName,
        'favoriteTeamId': favoriteTeamId,
        'favoritePlayerIds': favoritePlayerIds,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postOnboarding',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.onboardingUrl, 'statusCode': response.statusCode},
      );
      throw ApiStatusException(response.statusCode);
    }
    SentryLogger.info(module: 'API', eventName: 'postOnboarding');
  }
}
