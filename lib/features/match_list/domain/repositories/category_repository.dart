import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/features/match_list/domain/category_tree.dart';

/// 카테고리(리그/시즌/팀) 트리 조회.
abstract interface class CategoryRepository {
  /// 해당 연도의 리그/스플릿/팀 트리.
  ///
  /// 같은 연도 요청이 이미 떠 있거나 방금 끝났으면 그 결과를 재사용한다 —
  /// 응답이 0.9~2.7 초씩 걸려(2026-08-12 실측) 화면 진입마다 다시 받으면
  /// 그대로 맨 앞에 깔린다.
  Future<Either<Failure, CategoryTree>> fetchTree({required int year});
}
