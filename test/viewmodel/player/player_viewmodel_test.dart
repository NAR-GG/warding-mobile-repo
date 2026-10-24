import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/player_detail.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/repository/player/player_mock_source.dart';
import 'package:warding/screens/player/component/player_next_match_card.dart';
import 'package:warding/viewmodel/home/solo_cheer_controller.dart';
import 'package:warding/viewmodel/player/player_viewmodel.dart';

PlayerViewModel _vm(int id, {SoloCheerController? cheers}) => PlayerViewModel(
  playerId: id,
  source: const MockPlayerSource(),
  cheers: cheers,
  isLoggedIn: () async => false,
);

void main() {
  test('솔랭 중 선수 — 상세·탭을 읽고 응원 수를 공유 컨트롤러에 합친다', () async {
    final cheers = SoloCheerController(source: MockCheerSource());
    final vm = _vm(1, cheers: cheers);
    await vm.load();

    expect(vm.detail!.live, isNotNull);
    expect(vm.detail!.nextMatch!.bestOf, 1);
    expect(vm.worlds!.matches, hasLength(3));
    expect(vm.solo!.games, hasLength(20));
    // 홈과 같은 키(이름)로 합쳐 홈 카드와 숫자가 같다.
    expect(cheers.totalOf('Faker'), 1284);
    vm.dispose();
    cheers.dispose();
  });

  test('경기 기록이 아직 없으면 월즈 경기 목록이 빈다(집계 중)', () async {
    final vm = _vm(2);
    await vm.load();
    expect(vm.worlds!.matches, isEmpty);
    expect(vm.worlds!.rating, isNull);
    vm.dispose();
  });

  test('챔피언 정렬 — 고른 쪽 판수 많은 순', () async {
    final vm = _vm(1);
    await vm.load();
    expect(vm.sortedChampions.first.championName, '오로라');
    vm.setChampionSort(PlayerChampionSort.worlds);
    expect(vm.sortedChampions.first.worldsGames, 1);
    expect(vm.sortedChampions.first.championName, '아지르');
    vm.dispose();
  });

  test('비회원 구독 토글은 false — 화면이 로그인으로 보낸다', () async {
    final vm = _vm(1);
    await vm.load();
    expect(await vm.toggleSubscribed(), isFalse);
    expect(vm.detail!.subscribed, isTrue);
    vm.dispose();
  });

  test('해외 팀 코드가 null 이면 팀 이름으로 표시한다', () {
    final g = PlayerWorldsGame.fromJson({
      'win': true,
      'opponentTeamCode': null,
      'opponentTeamImageUrl': null,
      'opponentTeamName': 'LOS Grandes',
      'stage': '스위스',
    });
    expect(g.opponentLabel, 'LOS Grandes');
  });

  test('D-day 는 달력 날짜로 센다', () {
    final now = DateTime(2026, 10, 25, 23, 50);
    expect(daysUntil(DateTime(2026, 10, 26, 0, 10), now), 1);
    expect(daysUntil(DateTime(2026, 10, 25, 22), now), 0);
    expect(daysUntil(DateTime(2026, 10, 24, 22), now), isNull);
  });
}
