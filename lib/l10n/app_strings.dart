import 'app_localizations.dart';

import '../config/app_globals.dart';

/// BuildContext 없이 현재 언어의 문자열을 가져오는 헬퍼.
///
/// ViewModel·Model 등 위젯 트리 밖에서 다국어 문자열이 필요할 때 사용한다.
/// navigatorKey 의 context 를 통해 현재 로케일의 AppLocalizations 를 조회한다.
/// context 가 아직 없으면 (앱 시작 직후) null 을 반환한다.
AppLocalizations? get appStrings {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return null;
  return AppLocalizations.of(ctx);
}
