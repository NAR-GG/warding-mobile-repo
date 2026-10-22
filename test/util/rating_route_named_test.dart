import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 평점 화면을 띄우는 모든 `push` 에 **라우트 이름이 붙어 있는지** 소스에서
/// 확인한다.
///
/// 왜 소스를 읽나: 진입 경로가 홈·경기 상세·내가 쓴 리뷰 세 곳인데 각각
/// ViewModel·API 를 다 세워야 위젯 테스트가 돌아간다. 반면 확인할 것은
/// "이름을 붙였나" 한 줄이라, 소스 검사가 더 싸고 세 경로를 한 번에 덮는다.
///
/// 무엇을 막나: 이름 없는 `MaterialPageRoute` 는 observer 가 **시트·다이얼로그로
/// 보고 무시한다**(`_isPageRoute`). 그래서
/// - `page_view(player_rating)` 이 안 찍히고 — 화면이 집계에서 통째로 빠진다
///   (실제로 경기 상세·내가 쓴 리뷰 두 경로가 그 상태였다)
/// - 돌아올 때 `didPop` 도 복귀로 안 세서 **`prev_page` 가 옛 화면에 머문다**
///
/// 둘 다 조용히 틀리는 종류라(에러도 경고도 없다) 값으로 박아 둔다.
void main() {
  test('PlayerRatingScreen 을 띄우는 모든 라우트에 이름이 있다', () {
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      // `MaterialPageRoute<...>(` 부터 괄호가 닫히는 데까지를 한 블록으로 본다.
      for (final match
          in RegExp(r'MaterialPageRoute<[^>]*>\s*\(').allMatches(source)) {
        var i = match.end;
        var depth = 1;
        while (i < source.length && depth > 0) {
          if (source[i] == '(') {
            depth++;
          } else if (source[i] == ')') {
            depth--;
          }
          i++;
        }
        final block = source.substring(match.end, i);
        if (!block.contains('PlayerRatingScreen')) continue;
        // 일시 제거(검증용)
        final line = source.substring(0, match.start).split('\n').length;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '이름 없이 평점 화면을 띄우면 page_view 가 누락되고 prev_page 가 어긋난다. '
          'settings: RouteSettings(name: AnalyticsPage.playerRating) 를 붙인다. '
          '누락: $offenders',
    );
  });
}
