import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/team/team_logo_directory.dart';

void main() {
  test('불러온 팀 코드로 로고를 찾는다(대소문자 무시)', () async {
    final dir = TeamLogoDirectory(
      load: () async => const [
        TeamLogoEntry('T1', 'https://img/t1.png'),
        TeamLogoEntry('GEN', 'https://img/gen.png'),
        TeamLogoEntry('NOLOGO', ''),
      ],
    );

    expect(dir.logoFor('T1'), isNull);
    dir.ensureLoaded();
    await pumpEventQueue();

    expect(dir.logoFor('T1'), 'https://img/t1.png');
    expect(dir.logoFor('gen'), 'https://img/gen.png');
    expect(dir.logoFor('NOLOGO'), isNull);
    expect(dir.logoFor('HLE'), isNull);
  });

  test('여러 번 불러도 요청은 한 번', () async {
    var calls = 0;
    final dir = TeamLogoDirectory(
      load: () async {
        calls++;
        return const [TeamLogoEntry('T1', 'https://img/t1.png')];
      },
    );

    dir
      ..ensureLoaded()
      ..ensureLoaded()
      ..ensureLoaded();
    await pumpEventQueue();
    dir.ensureLoaded();
    await pumpEventQueue();

    expect(calls, 1);
  });

  test('실패하면 예외 없이 비어 있고, 곧바로 다시 시도하지는 않는다', () async {
    var calls = 0;
    final dir = TeamLogoDirectory(
      load: () async {
        calls++;
        throw Exception('fail');
      },
    );

    dir.ensureLoaded();
    await pumpEventQueue();
    dir.ensureLoaded();
    await pumpEventQueue();

    expect(calls, 1);
    expect(dir.logoFor('T1'), isNull);
  });
}
