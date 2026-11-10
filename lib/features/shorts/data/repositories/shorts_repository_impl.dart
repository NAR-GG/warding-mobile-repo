import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/data/failure_mapper.dart';
import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/features/shorts/data/mappers/shorts_mapper.dart';
import 'package:warding/features/shorts/data/models/story_video_dto.dart';
import 'package:warding/features/shorts/domain/entities/story_video.dart';
import 'package:warding/features/shorts/domain/repositories/shorts_repository.dart';

/// [ShortsRepository] 의 원격 구현. 인증이 필요 없다(비회원도 본다).
class ShortsRepositoryImpl implements ShortsRepository {
  @override
  Future<Either<Failure, ShortsPage>> fetchShortsPage({
    String sort = 'latest',
    int size = 20,
    int page = 0,
    String? teamCode,
  }) async {
    final url = ApiConfig.shortsUrl(
      sort: sort,
      size: size,
      page: page,
      teamCode: teamCode,
    );
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiStatusException(response.statusCode, endpoint: url);
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final dtos = (data['content'] as List<dynamic>? ?? const [])
          .map((e) => StoryVideoDto.fromJson(e as Map<String, dynamic>))
          .toList();
      return Right(
        ShortsMapper.pageToDomain(
          dtos,
          isLast: data['last'] as bool? ?? true,
        ),
      );
    } catch (e) {
      return Left(toFailure(e, op: 'fetchShortsPage'));
    }
  }
}
