import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/data/failure_mapper.dart';
import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/features/match_list/domain/category_tree.dart';
import 'package:warding/features/match_list/domain/repositories/category_repository.dart';

/// [CategoryRepository] 의 원격 구현.
///
/// DTO/Entity 를 가르지 않는다. [CategoryTree] 는 중첩 클래스 5 개(90 줄)라
/// 복제하면 Mapper 까지 260 줄이 되는데, 얻는 것은 서버 필드명 변경의 격리
/// 하나뿐이다. 트리 구조가 서버 스펙과 1:1 이고 파생 로직도 없어서 그대로 쓴다.
class CategoryRepositoryImpl implements CategoryRepository {
  /// 진행 중인 트리 요청 + 캐시. 연도 안에서는 시즌 도중 거의 안 바뀐다.
  final Map<int, Future<Either<Failure, CategoryTree>>> _inFlight = {};
  final Map<int, (DateTime, CategoryTree)> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  @override
  Future<Either<Failure, CategoryTree>> fetchTree({required int year}) {
    final cached = _cache[year];
    if (cached != null && DateTime.now().difference(cached.$1) < _cacheTtl) {
      debugPrint('[Category] tree cache hit: $year');
      return Future.value(Right(cached.$2));
    }
    final inFlight = _inFlight[year];
    if (inFlight != null) {
      debugPrint('[Category] tree 요청 합류: $year');
      return inFlight;
    }

    // **성공만 캐시한다.** 실패한 Either 를 캐시하면 TTL 동안 같은 실패가
    // 재생되어 재시도가 막힌다.
    final request = _fetchTree(year).then((result) {
      result.match((_) {}, (tree) => _cache[year] = (DateTime.now(), tree));
      return result;
    });
    // 끝나면 진행 중 표시를 지운다. 그 사이 새 요청이 들어와 있으면 그 쪽을
    // 지우지 않도록 확인한다.
    unawaited(request.whenComplete(() {
      if (identical(_inFlight[year], request)) _inFlight.remove(year);
    }));
    _inFlight[year] = request;
    return request;
  }

  Future<Either<Failure, CategoryTree>> _fetchTree(int year) async {
    final url = ApiConfig.categoriesTreeUrl(year: year);
    final sw = Stopwatch()..start();
    debugPrint('[Category] GET $url');
    try {
      final response = await http.get(Uri.parse(url));
      sw.stop();
      debugPrint('[Category] tree ← ${response.statusCode} '
          '(${sw.elapsedMilliseconds}ms)');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiStatusException(response.statusCode, endpoint: url);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(CategoryTree.fromJson(body));
    } catch (e) {
      return Left(toFailure(e, op: 'fetchTree'));
    }
  }
}
