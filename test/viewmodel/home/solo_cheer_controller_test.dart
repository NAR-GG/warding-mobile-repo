import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/viewmodel/home/solo_cheer_controller.dart';

/// 보낸 호출을 기록하고, 서버처럼 누적해 돌려주는 가짜 응원 소스.
class _FakeCheer implements CheerSource {
  final List<(int, int)> calls = [];
  int serverTotal = 100;
  int serverMine = 0;
  Object? failWith;

  @override
  Future<CheerResult> send(int playerId, int count) async {
    final err = failWith;
    if (err != null) throw err;
    calls.add((playerId, count));
    serverTotal += count;
    serverMine += count;
    return CheerResult(total: serverTotal, mine: serverMine);
  }
}

void main() {
  late _FakeCheer source;
  late SoloCheerController c;

  setUp(() {
    source = _FakeCheer();
    c = SoloCheerController(
      source: source,
      debounce: const Duration(milliseconds: 50),
      maxWait: const Duration(milliseconds: 200),
    );
    addTearDown(c.dispose);
    c.sync('Faker', total: 100, mine: 0, playerId: 7);
  });

  Future<void> wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  test('탭은 숫자를 바로 올리고, 전송은 마지막 탭 뒤 한 번에 count 로 묶는다', () async {
    c.tap('Faker');
    c.tap('Faker');
    c.tap('Faker');
    expect(c.totalOf('Faker'), 103);
    expect(c.mineOf('Faker'), 3);
    expect(source.calls, isEmpty);

    await wait(120);
    expect(source.calls, [(7, 3)]);
    expect(c.pendingOf('Faker'), 0);
    expect(c.totalOf('Faker'), 103);
  });

  test('계속 눌러도 maxWait 가 지나면 중간에 한 번 보낸다', () async {
    for (var i = 0; i < 8; i++) {
      c.tap('Faker');
      await wait(40); // debounce(50) 보다 짧게 계속 누른다.
    }
    expect(source.calls, isNotEmpty);
    await wait(120);
    expect(source.calls.fold<int>(0, (a, e) => a + e.$2), 8);
  });

  test('30개를 넘으면 30씩 나눠 보낸다', () async {
    for (var i = 0; i < 65; i++) {
      c.tap('Faker');
    }
    await c.flushAll();
    expect(source.calls, [(7, 30), (7, 30), (7, 5)]);
  });

  test('전송이 실패해도 숫자를 되돌리지 않고, 다음 flush 에 다시 보낸다', () async {
    source.failWith = Exception('network');
    c.tap('Faker');
    c.tap('Faker');
    await c.flushAll();
    expect(c.totalOf('Faker'), 102);
    expect(c.pendingOf('Faker'), 2);

    source.failWith = null;
    c.tap('Faker');
    await c.flushAll();
    expect(source.calls, [(7, 3)]);
    expect(c.pendingOf('Faker'), 0);
  });

  test('서버가 거절(409)하면 미결을 버리고 숫자는 유지한다', () async {
    source.failWith = const CheerRejected(409);
    c.tap('Faker');
    await c.flushAll();
    expect(c.pendingOf('Faker'), 0);
    expect(c.totalOf('Faker'), 101);
  });

  test('서버 폴링 값은 내 낙관적 수보다 작으면 무시한다(줄어들지 않는다)', () {
    c.tap('Faker');
    c.tap('Faker');
    c.sync('Faker', total: 101, mine: 0);
    expect(c.totalOf('Faker'), 102);
    expect(c.mineOf('Faker'), 2);
    // 다른 팬이 더 눌러 서버 값이 더 크면 따라간다.
    c.sync('Faker', total: 150, mine: 2);
    expect(c.totalOf('Faker'), 150);
  });

  test('카드가 사라진 선수의 미결은 flushMissing 이 보낸다', () async {
    c.sync('Chovy', total: 5, mine: 0, playerId: 9);
    c.tap('Faker');
    c.tap('Chovy');
    await c.flushMissing({'Faker'});
    expect(source.calls, [(9, 1)]);
    expect(c.pendingOf('Faker'), 1);
    await c.flushAll();
  });
}
