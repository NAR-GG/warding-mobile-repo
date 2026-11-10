import 'package:get_it/get_it.dart';

import 'package:warding/features/my_review/data/repositories/my_review_repository_impl.dart';
import 'package:warding/features/match_list/data/repositories/category_repository_impl.dart';
import 'package:warding/features/match_list/domain/repositories/category_repository.dart';
import 'package:warding/features/shorts/data/repositories/shorts_repository_impl.dart';
import 'package:warding/features/shorts/domain/repositories/shorts_repository.dart';
import 'package:warding/features/my_review/domain/repositories/my_review_repository.dart';

/// 의존성 컨테이너.
///
/// ViewModel 이 구현체를 직접 `new` 하지 않게 한다. 그래야 테스트에서
/// 인터페이스 Mock 을 끼울 수 있고, 플랫폼·환경별로 구현을 갈아끼울 수 있다.
final GetIt di = GetIt.instance;

/// `main()` 에서 `runApp` 전에 한 번 부른다.
///
/// `registerLazySingleton` 을 쓰는 이유는 앱이 켜질 때 쓰지 않는 기능의 객체까지
/// 만들 필요가 없어서다 — 첫 참조 시점에 생성된다.
void configureDependencies() {
  // 이미 등록돼 있으면 (테스트에서 두 번 부르는 경우) 지우고 다시 세운다.
  if (di.isRegistered<MyReviewRepository>()) return;

  // ── my_review ────────────────────────────────────────────────
  di.registerLazySingleton<MyReviewRepository>(MyReviewRepositoryImpl.new);

  // ── shorts ───────────────────────────────────────────────────
  di.registerLazySingleton<ShortsRepository>(ShortsRepositoryImpl.new);

  // ── match_list ───────────────────────────────────────────────
  di.registerLazySingleton<CategoryRepository>(CategoryRepositoryImpl.new);
}

/// 테스트에서 등록을 비운다. 앱 코드는 부르지 않는다.
Future<void> resetDependenciesForTest() => di.reset();
