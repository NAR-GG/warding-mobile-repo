import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/notice.dart';
import 'package:warding/repository/notice/notice_repository.dart';
import 'package:warding/viewmodel/notice/notice_viewmodel.dart';

class MockNoticeRepository extends Mock implements NoticeRepository {}

Notice _notice(int id) => Notice(
      id: id,
      title: '공지 $id',
      content: '본문',
      pinned: false,
      publishedAt: DateTime(2026, 7, id),
    );

void main() {
  late MockNoticeRepository repo;
  setUp(() => repo = MockNoticeRepository());

  test('첫 페이지 로드 후 last=false면 loadMore로 다음 페이지 누적', () async {
    when(() => repo.fetchNotices(page: 0, size: any(named: 'size')))
        .thenAnswer((_) async =>
            NoticePage(notices: [_notice(1), _notice(2)], last: false));
    when(() => repo.fetchNotices(page: 1, size: any(named: 'size')))
        .thenAnswer(
            (_) async => NoticePage(notices: [_notice(3)], last: true));

    final vm = NoticeViewModel(repository: repo);
    await Future<void>.delayed(Duration.zero); // 생성자 내 첫 로드 대기

    expect(vm.notices, hasLength(2));
    expect(vm.hasMore, isTrue);

    await vm.loadMore();
    expect(vm.notices, hasLength(3));
    expect(vm.hasMore, isFalse);

    // last 이후엔 더 호출하지 않는다.
    await vm.loadMore();
    verifyNever(() => repo.fetchNotices(page: 2, size: any(named: 'size')));
  });

  test('첫 로드 실패 시 failed=true', () async {
    when(() => repo.fetchNotices(page: 0, size: any(named: 'size')))
        .thenThrow(Exception('network'));

    final vm = NoticeViewModel(repository: repo);
    await Future<void>.delayed(Duration.zero);

    expect(vm.failed, isTrue);
    expect(vm.notices, isEmpty);
  });
}
