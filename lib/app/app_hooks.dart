import 'package:warding/core/di_container.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/core/infrastructure/live_activity/live_activity_logo_prefetcher.dart';
import 'package:warding/core/infrastructure/team/team_logo_directory.dart';
import 'package:warding/features/login/presentation/screens/login_screen.dart';
import 'package:warding/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:warding/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:warding/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:warding/features/subscription/domain/repositories/subscription_repository.dart';

/// core 가 기능을 직접 import 하지 않도록, core 쪽에 비워 둔 자리를 앱이 채운다.
///
/// `configureDependencies` 다음에 한 번 부른다(`main.dart`, `test/flutter_test_config.dart`).
/// 여러 번 불려도 같은 값으로 덮어쓸 뿐이다.
void configureAppHooks() {
  AuthService.loginScreenBuilder = (_) => const LoginScreen();

  // 캐시 비우기는 Impl 관심사라 Interface 에 올리지 않았다 — 로그아웃 때만
  // 필요하고, 다른 구현(목업 등)에는 캐시가 없을 수 있다.
  AuthService.onSignedOut
    ..clear()
    ..add(
      () => (di<SubscriptionRepository>() as SubscriptionRepositoryImpl)
          .clearCache(),
    );

  // 프리페치할 팀 목록은 일정 필터 API 가 준다 — core 는 그 기능을 모르므로
  // 여기서 꽂는다. 실패하면 빈 목록(프리페치 생략)으로 둔다.
  LiveActivityLogoPrefetcher.teamTargetsLoader = (league) async {
    final options = await di<ScheduleRepository>().fetchFilterOptions(
      league: league,
    );
    return options.match(
      (_) => const <LogoTarget>[],
      (o) => [
        for (final t in o.teams)
          LogoTarget(code: t.teamCode, imageUrl: t.teamImageUrl),
      ],
    );
  };

  TeamLogoDirectory.defaultLoader = () async {
    final teams = (await di<OnboardingRepository>().fetchTeams())
        .getOrElse((_) => const []);
    return [for (final t in teams) TeamLogoEntry(t.code, t.imageUrl)];
  };
}
