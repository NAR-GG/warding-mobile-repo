import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/repository/preference/notice_preference_repository.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/schedule/schedule_viewmodel.dart';

/// 캘린더 상단 띠배너가 **첫 프레임부터** 확정되는지.
///
/// 배너는 캘린더 위에 얹혀 있어서, 뒤늦게 나타나면 그 순간 캘린더를 아래로
/// 밀고 높이까지 줄인다 — 화면이 한 번 출렁이고 셀 레이아웃이 통째로 다시
/// 잡힌다. 스플래시가 미리 받아 두는 이유가 그것이라, 뷰모델이 그 결과를
/// 생성 즉시(동기로) 집어야 의미가 있다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notices = NoticeRepository.instance;
  final noticePrefs = NoticePreferenceRepository.instance;

  String bannerBody(List<int> ids) => jsonEncode([
        for (final id in ids)
          {
            'id': id,
            'title': '공지 $id',
            'content': '',
            'pinned': false,
            'publishedAt': '2026-08-19T10:00:00',
          },
      ]);

  /// 배너 조회만 [body] 로 답하고, 나머지(캘린더 등)는 빈 응답으로 흘린다.
  /// 이 테스트의 관심사는 배너뿐이라 캘린더는 성립만 시킨다.
  void mockApi(String body) {
    api.setApiClientForTesting(MockClient((request) async {
      final headers = {'content-type': 'application/json; charset=utf-8'};
      if (request.url.path.contains('notice')) {
        return http.Response(body, 200, headers: headers);
      }
      return http.Response('[]', 200, headers: headers);
    }));
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
    notices.resetPromotedCacheForTesting();
    noticePrefs.resetCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('스플래시가 미리 받아 뒀으면 생성 직후(await 없이) 배너를 안다', () async {
    mockApi(bannerBody([1]));
    // 스플래시의 프리페치에 해당.
    await notices.fetchPromoted();

    final vm = ScheduleViewModel();
    addTearDown(vm.dispose);

    // await 을 한 번도 끼우지 않은 이 시점이 곧 첫 프레임이다.
    expect(
      vm.promotedNotice?.id,
      1,
      reason: '여기서 null 이면 배너 없는 화면이 한 번 그려졌다가 끼어든다',
    );
  });

  test('프리페치가 없었으면 첫 프레임엔 배너가 없고, 받은 뒤에 알린다', () async {
    mockApi(bannerBody([2]));

    final vm = ScheduleViewModel();
    addTearDown(vm.dispose);
    expect(vm.promotedNotice, isNull);

    var notified = false;
    vm.addListener(() => notified = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.promotedNotice?.id, 2);
    expect(notified, isTrue, reason: '뒤늦게 온 배너는 화면에 알려야 한다');
  });

  test('이미 닫은 공지는 첫 프레임에도 배너로 뜨지 않는다', () async {
    mockApi(bannerBody([3]));
    await noticePrefs.addDismissedId(3);
    await notices.fetchPromoted();

    final vm = ScheduleViewModel();
    addTearDown(vm.dispose);

    expect(
      vm.promotedNotice,
      isNull,
      reason: '닫은 배너가 한 프레임 보였다 사라지면 캘린더가 두 번 밀린다',
    );
  });

  test('프리페치 결과와 같으면 배너는 그대로 유지된다', () async {
    mockApi(bannerBody([4]));
    await notices.fetchPromoted();

    final vm = ScheduleViewModel();
    addTearDown(vm.dispose);
    expect(vm.promotedNotice?.id, 4);

    // 배너 값이 흔들리지 않는지만 본다. 뷰모델은 캘린더·선호팀 로드로도
    // 알리므로, notify 횟수로는 배너 때문인지 구분되지 않는다.
    final seen = <int?>{};
    vm.addListener(() => seen.add(vm.promotedNotice?.id));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.promotedNotice?.id, 4);
    expect(
      seen.where((id) => id != 4),
      isEmpty,
      reason: '조회 결과가 같은데 배너가 잠깐이라도 바뀌면 캘린더가 밀린다',
    );
  });

  test('✕ 로 닫으면 배너가 사라진다', () async {
    mockApi(bannerBody([5, 6]));
    await notices.fetchPromoted();

    final vm = ScheduleViewModel();
    addTearDown(vm.dispose);
    expect(vm.promotedNotice?.id, 5);

    vm.dismissPromotedNotice();

    // 닫으면 다음으로 안 닫은 배너가 이어서 뜬다.
    expect(vm.promotedNotice?.id, 6);
  });
}
