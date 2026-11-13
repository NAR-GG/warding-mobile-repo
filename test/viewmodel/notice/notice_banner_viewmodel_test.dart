import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/core/infrastructure/preference/notice_preference_repository.dart';
import 'package:warding/features/notice/domain/notice.dart';
import 'package:warding/features/notice/domain/repositories/notice_repository.dart';
import 'package:warding/features/notice/presentation/viewmodels/notice_banner_viewmodel.dart';

class _MockRepo extends Mock implements NoticeRepository {}

class _MockPrefs extends Mock implements NoticePreferenceRepository {}

Notice _notice(int id) =>
    Notice(id: id, title: '공지$id', content: '', pinned: false);

void main() {
  late _MockRepo repo;
  late _MockPrefs prefs;

  NoticeBannerViewModel build() =>
      NoticeBannerViewModel(repository: repo, preferences: prefs);

  setUp(() {
    repo = _MockRepo();
    prefs = _MockPrefs();
    // 기본값 — 캐시 없음.
    when(() => repo.cachedPromoted).thenReturn(null);
    when(() => prefs.cachedValue).thenReturn(null);
    when(() => prefs.addDismissedId(any())).thenAnswer((_) async {});
  });

  test('스플래시가 받아 둔 캐시는 생성 시점에 반영한다', () {
    // 첫 프레임부터 배너를 그려야 뒤늦게 끼어들어 아래 섹션을 밀지 않는다.
    when(() => repo.cachedPromoted).thenReturn([_notice(1)]);

    final vm = build();

    expect(vm.notice?.id, 1);
    expect(vm.visible, isTrue);
  });

  test('캐시가 없으면 배너를 숨긴 상태로 시작한다', () {
    final vm = build();

    expect(vm.notice, isNull);
    expect(vm.visible, isFalse);
  });

  test('닫지 않은 것 중 첫 공지를 고른다', () async {
    when(() => repo.fetchPromoted())
        .thenAnswer((_) async => Right([_notice(1), _notice(2)]));
    when(() => prefs.loadDismissedIds()).thenAnswer((_) async => {1});

    final vm = build();
    await vm.load();

    expect(vm.notice?.id, 2);
  });

  test('전부 닫았으면 배너를 숨긴다', () async {
    when(() => repo.fetchPromoted())
        .thenAnswer((_) async => Right([_notice(1)]));
    when(() => prefs.loadDismissedIds()).thenAnswer((_) async => {1});

    final vm = build();
    await vm.load();

    expect(vm.visible, isFalse);
  });

  test('조회하는 사이 닫은 id 는 저장값에 덮이지 않는다', () async {
    when(() => repo.fetchPromoted())
        .thenAnswer((_) async => Right([_notice(1), _notice(2)]));
    // 저장소는 아직 1 을 모른다(응답이 늦게 옴).
    when(() => prefs.loadDismissedIds()).thenAnswer((_) async => <int>{});
    when(() => repo.cachedPromoted).thenReturn([_notice(1), _notice(2)]);

    final vm = build();
    vm.dismiss(); // 1 을 닫는다
    await vm.load();

    // 덮어썼으면 1 이 다시 떴을 것이다.
    expect(vm.notice?.id, 2);
  });

  test('dismiss 는 저장소에 기록하고 통지한다', () async {
    when(() => repo.cachedPromoted).thenReturn([_notice(9)]);

    final vm = build();
    var notified = 0;
    vm.addListener(() => notified++);
    vm.dismiss();

    expect(vm.visible, isFalse);
    expect(notified, 1);
    verify(() => prefs.addDismissedId(9)).called(1);

    // 보여줄 배너가 없으면 아무것도 하지 않는다.
    vm.dismiss();
    expect(notified, 1);
  });

  test('조회 실패는 삼키고 배너만 비운다', () async {
    when(() => repo.fetchPromoted())
        .thenAnswer((_) async => const Left(ServerFailure()));
    when(() => prefs.loadDismissedIds()).thenAnswer((_) async => <int>{});

    final vm = build();
    await vm.load();

    expect(vm.visible, isFalse);
  });
}
