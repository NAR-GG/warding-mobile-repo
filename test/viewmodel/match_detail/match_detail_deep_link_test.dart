import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/match_game.dart';
import 'package:warding/viewmodel/match_detail/match_detail_viewmodel.dart';

import '../../support/fake_rating_repository.dart';

/// 이미 떠 있는 상세 화면에 딥링크를 다시 적용하는 경로 검증.
///
/// Live Activity 카드·다이나믹 아일랜드·푸시를 연달아 누르면 예전엔 같은 경기
/// 상세가 스택에 계속 쌓였다. 지금은 화면을 새로 push 하지 않고
/// [MatchDetailViewModel.applyDeepLink] 로 탭·세트만 갈아끼운다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatchDetailRepository match;
  late MockRatingRepository rating;

  setUp(() {
    match = MockMatchDetailRepository();
    rating = MockRatingRepository();
    when(() => match.fetchChampionPick(any())).thenThrow(Exception('skip'));
    when(() => match.fetchLiveEvents(any())).thenThrow(Exception('skip'));
    when(() => rating.fetchGameRatings(any(), teamSide: any(named: 'teamSide')))
        .thenThrow(Exception('skip'));
  });

  MatchDetailViewModel vmFor(List<MatchGame> games) {
    when(() => match.fetchGames('m-1')).thenAnswer((_) async => (games, null));
    return MatchDetailViewModel(
      matchId: 'm-1',
      repository: match,
      ratingRepository: rating,
    );
  }

  const twoSets = [
    MatchGame(gameId: 'g1', gameOrder: 1, status: 'ENDED'),
    MatchGame(gameId: 'g2', gameOrder: 2, status: 'ENDED'),
  ];

  // 카드 본문(기본 탭)으로 들어온 뒤 '평점 남기기'(평점 탭 + 세트 지정)를
  // 누르는, Live Activity 에서 가장 흔한 연속 동작.
  test('세트를 지정한 딥링크가 오면 그 세트로 전환한다', () async {
    final vm = vmFor(twoSets);
    await vm.load();
    expect(vm.currentSet, 2); // 기본: 마지막 종료 세트

    vm.applyDeepLink(tabIndex: 2, setNumber: 1);

    expect(vm.currentSet, 1);
  });

  test('세트 없이 탭만 지정한 딥링크는 세트를 그대로 둔다', () async {
    final vm = vmFor(twoSets);
    await vm.load();

    vm.applyDeepLink(tabIndex: 1);

    expect(vm.currentSet, 2);
  });

  // 세트 목록에 없는 번호로 바꾸면 화면이 빈 세트를 가리키게 된다.
  test('목록에 없는 세트 번호는 무시한다', () async {
    final vm = vmFor(twoSets);
    await vm.load();

    vm.applyDeepLink(tabIndex: 2, setNumber: 9);

    expect(vm.currentSet, 2);
  });

  test('같은 딥링크가 여러 번 와도 상태가 흔들리지 않는다', () async {
    final vm = vmFor(twoSets);
    await vm.load();

    vm.applyDeepLink(tabIndex: 2, setNumber: 1);
    vm.applyDeepLink(tabIndex: 2, setNumber: 1);
    vm.applyDeepLink(tabIndex: 2, setNumber: 1);

    expect(vm.currentSet, 1);
  });

  test('딥링크 적용은 리스너에게 통지된다', () async {
    final vm = vmFor(twoSets);
    await vm.load();
    var notified = 0;
    vm.addListener(() => notified++);

    vm.applyDeepLink(tabIndex: 2, setNumber: 1);

    expect(notified, greaterThan(0));
  });
}
