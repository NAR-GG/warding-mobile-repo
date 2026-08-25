import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_poll.dart';

/// 투표에서 유일하게 비자명한 건 "결과를 언제 보여주느냐" 다.
void main() {
  CommunityPoll poll({bool hide = true, int? myChoice}) => CommunityPoll(
    question: '3세트 패배 원인은?',
    options: const [
      CommunityPollOption(label: '밴픽', votes: 6),
      CommunityPollOption(label: '정글 동선', votes: 3),
      CommunityPollOption(label: '그냥 상대가 잘함', votes: 1),
    ],
    hideResultsUntilVoted: hide,
    myChoice: myChoice,
  );

  test('기본값은 투표해야 결과가 보인다', () {
    expect(poll().hideResultsUntilVoted, isTrue);
    expect(poll().resultsVisible, isFalse);
  });

  test('투표하면 결과가 열린다', () {
    expect(poll().vote(0).resultsVisible, isTrue);
  });

  test('미리보기를 켠 투표는 투표 전에도 결과가 보인다', () {
    expect(poll(hide: false).resultsVisible, isTrue);
  });

  test('투표하면 그 항목의 표만 늘고 내 선택이 기록된다', () {
    final voted = poll().vote(1);
    expect(voted.myChoice, 1);
    expect(voted.options[1].votes, 4);
    expect(voted.options[0].votes, 6);
    expect(voted.totalVotes, 11);
  });

  test('두 번 투표해도 표가 더 늘지 않는다', () {
    final once = poll().vote(0);
    expect(once.vote(2).myChoice, 0);
    expect(once.vote(2).totalVotes, once.totalVotes);
  });

  test('투표 후에도 미리보기 설정은 유지된다', () {
    expect(poll(hide: false).vote(0).hideResultsUntilVoted, isFalse);
  });

  test('아무도 투표하지 않았으면 비율은 0 이다 (0 나누기 방지)', () {
    const empty = CommunityPoll(
      question: '?',
      options: [
        CommunityPollOption(label: 'A', votes: 0),
        CommunityPollOption(label: 'B', votes: 0),
      ],
    );
    expect(empty.ratio(0), 0);
  });
}
