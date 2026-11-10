import 'dart:async';

import 'package:warding/core/di_container.dart';

/// `test/` 하위 모든 테스트 실행 전에 Flutter 가 자동으로 부르는 훅.
///
/// 의존성을 한 번 등록한다. ViewModel 은 주입을 안 받으면 `di<X>()` 를 기본값으로
/// 쓰는데, 등록이 없으면 **생성 자체가 터진다**(`GetIt: ... is not registered`).
/// 그런데 이건 런타임 오류라 `flutter analyze` 가 잡지 못한다 — 실제로
/// `ShortsRepository` 를 인터페이스로 바꿨을 때 repository 를 주입하지 않는 기존
/// 테스트 111 개가 한꺼번에 깨졌다.
///
/// 등록되는 것은 실제 구현이지만, 네트워크를 타는 테스트는 어차피
/// `api_client` 의 HTTP 클라이언트를 가짜로 갈아끼운다. repository 를 직접
/// 주입하는 테스트는 기본값을 쓰지 않으므로 영향이 없다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  configureDependencies();
  await testMain();
}
