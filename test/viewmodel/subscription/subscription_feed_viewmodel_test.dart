import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/member_notification.dart';
import 'package:warding/repository/notification/member_notification_repository.dart';
import 'package:warding/viewmodel/subscription/subscription_feed_viewmodel.dart';

class MockRepo extends Mock implements MemberNotificationRepository {}

MemberNotification _n(int id, {bool read = false}) =>
    MemberNotification.fromJson({
      'id': id,
      'type': 'SET_START',
      'read': read,
      'createdAt': '2026-06-24T10:00:00',
    });

MemberNotificationPage _page(List<MemberNotification> items, int unread) =>
    MemberNotificationPage(
      notifications: items,
      unreadCount: unread,
      page: 0,
      size: 50,
      totalElements: items.length,
      totalPages: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 뷰모델 생성 시 refreshNotificationPermission() 이 permission_handler 를
  // 통해 네이티브 채널을 호출하는데, 테스트 환경엔 네이티브 구현이 없으니
  // 미허용(0) 상태로 응답하도록 채널을 목킹한다.
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(permissionChannel, (call) async {
    if (call.method == 'checkPermissionStatus') return 0;
    return null;
  });

  late MockRepo repo;
  setUp(() => repo = MockRepo());

  test('load: 서버 피드와 미읽음 수를 반영', () async {
    when(() => repo.fetchNotifications(
          page: any(named: 'page'),
          size: any(named: 'size'),
        )).thenAnswer((_) async => _page([_n(1), _n(2, read: true)], 1));

    final vm = SubscriptionFeedViewModel(repository: repo);
    await vm.load();

    expect(vm.notifications, hasLength(2));
    expect(vm.unreadCount, 1);
    expect(vm.error, isNull);
  });

  test('markRead: 낙관적 read=true + 미읽음 감소 + 서버 호출', () async {
    when(() => repo.fetchNotifications(
          page: any(named: 'page'),
          size: any(named: 'size'),
        )).thenAnswer((_) async => _page([_n(1)], 1));
    when(() => repo.markRead(any())).thenAnswer((_) async {});

    final vm = SubscriptionFeedViewModel(repository: repo);
    await vm.load();
    expect(vm.unreadCount, 1);

    await vm.markRead(vm.notifications.first);

    expect(vm.notifications.first.read, isTrue);
    expect(vm.unreadCount, 0);
    verify(() => repo.markRead(1)).called(1);
  });

  test('load 실패: error 세팅, 빈 목록 유지', () async {
    when(() => repo.fetchNotifications(
          page: any(named: 'page'),
          size: any(named: 'size'),
        )).thenThrow(Exception('boom'));

    final vm = SubscriptionFeedViewModel(repository: repo);
    await vm.load();

    expect(vm.error, isNotNull);
    expect(vm.notifications, isEmpty);
  });

  test('delete: 낙관적 제거 + 서버 호출', () async {
    when(() => repo.fetchNotifications(
          page: any(named: 'page'),
          size: any(named: 'size'),
        )).thenAnswer((_) async => _page([_n(1), _n(2)], 0));
    when(() => repo.delete(any())).thenAnswer((_) async {});

    final vm = SubscriptionFeedViewModel(repository: repo);
    await vm.load();

    await vm.delete(vm.notifications.first);

    expect(vm.notifications.map((n) => n.id), [2]);
    verify(() => repo.delete(1)).called(1);
  });

  test('delete 실패: 항목 원위치 복구 + rethrow', () async {
    when(() => repo.fetchNotifications(
          page: any(named: 'page'),
          size: any(named: 'size'),
        )).thenAnswer((_) async => _page([_n(1), _n(2)], 0));
    when(() => repo.delete(any())).thenThrow(Exception('fail'));

    final vm = SubscriptionFeedViewModel(repository: repo);
    await vm.load();

    await expectLater(vm.delete(_n(1)), throwsException);
    expect(vm.notifications.map((n) => n.id), [1, 2]);
  });

  group('markAllReadOnExit', () {
    test('미읽음이 있으면 전체 읽음 API 를 부르고 목록은 건드리지 않는다', () async {
      when(() => repo.fetchNotifications(
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenAnswer((_) async => _page([_n(1), _n(2, read: true)], 1));
      when(() => repo.markAllRead(group: any(named: 'group')))
          .thenAnswer((_) async {});

      final vm = SubscriptionFeedViewModel(repository: repo);
      await vm.load();

      await vm.markAllReadOnExit();

      verify(() => repo.markAllRead(group: null)).called(1);
      // 화면이 사라지는 시점이라 낙관적 갱신을 하지 않는다 —
      // 머무는 동안 미읽음 강조가 유지되는 게 이 방식의 핵심이다.
      expect(vm.notifications.first.read, isFalse);
      expect(vm.unreadCount, 1);
    });

    test('조회가 끝났고 미읽음이 0 이면 API 를 부르지 않는다', () async {
      when(() => repo.fetchNotifications(
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenAnswer((_) async => _page([_n(1, read: true)], 0));

      final vm = SubscriptionFeedViewModel(repository: repo);
      await vm.load();

      await vm.markAllReadOnExit();

      verifyNever(() => repo.markAllRead(group: any(named: 'group')));
    });

    // _unreadCount 는 0 에서 시작한다. 조회 완료 여부를 구분하지 않으면
    // 목록이 뜨기 전에 나간 사용자의 알림이 미읽음으로 남는다.
    test('첫 조회가 끝나기 전에 나가면 미읽음 0 이어도 API 를 부른다', () async {
      // 생성자의 load() 가 끝나지 않도록 영원히 멈춰 둔다.
      when(() => repo.fetchNotifications(
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenAnswer((_) => Completer<MemberNotificationPage>().future);
      when(() => repo.markAllRead(group: any(named: 'group')))
          .thenAnswer((_) async {});

      final vm = SubscriptionFeedViewModel(repository: repo);
      expect(vm.unreadCount, 0);

      await vm.markAllReadOnExit();

      verify(() => repo.markAllRead(group: null)).called(1);
    });

    test('조회가 실패했으면 미읽음 0 이어도 API 를 부른다', () async {
      when(() => repo.fetchNotifications(
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenThrow(Exception('boom'));
      when(() => repo.markAllRead(group: any(named: 'group')))
          .thenAnswer((_) async {});

      final vm = SubscriptionFeedViewModel(repository: repo);
      await vm.load();
      expect(vm.unreadCount, 0);

      await vm.markAllReadOnExit();

      verify(() => repo.markAllRead(group: null)).called(1);
    });

    test('실패해도 예외를 던지지 않는다 (dispose 에서 불린다)', () async {
      when(() => repo.fetchNotifications(
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenAnswer((_) async => _page([_n(1)], 1));
      when(() => repo.markAllRead(group: any(named: 'group')))
          .thenThrow(Exception('boom'));

      final vm = SubscriptionFeedViewModel(repository: repo);
      await vm.load();

      await expectLater(vm.markAllReadOnExit(), completes);
    });

    test('group 범위를 그대로 넘긴다 (알림함은 COMMUNITY)', () async {
      when(() => repo.fetchNotifications(
            group: any(named: 'group'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).thenAnswer((_) async => _page([_n(1)], 1));
      when(() => repo.markAllRead(group: any(named: 'group')))
          .thenAnswer((_) async {});

      final vm = SubscriptionFeedViewModel(
        repository: repo,
        group: 'COMMUNITY',
      );
      await vm.load();

      await vm.markAllReadOnExit();

      verify(() => repo.markAllRead(group: 'COMMUNITY')).called(1);
    });
  });

  test('deleteAll: 목록 비우고 미읽음 0', () async {
    when(() => repo.fetchNotifications(
          page: any(named: 'page'),
          size: any(named: 'size'),
        )).thenAnswer((_) async => _page([_n(1), _n(2)], 2));
    when(() => repo.deleteAll()).thenAnswer((_) async => 2);

    final vm = SubscriptionFeedViewModel(repository: repo);
    await vm.load();

    await vm.deleteAll();

    expect(vm.notifications, isEmpty);
    expect(vm.unreadCount, 0);
    verify(() => repo.deleteAll()).called(1);
  });
}
