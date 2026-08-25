/// 게시글에 붙는 투표.
///
/// 1차 범위는 **항목 2~5개 · 단일 선택 · 마감 없음**까지다. 복수 선택·마감 기한·
/// 익명 투표는 스키마와 집계 분기를 늘리는 데 비해 첫 버전에서 쓸 사람이 거의
/// 없어 뺐다.
class CommunityPoll {
  const CommunityPoll({
    required this.question,
    required this.options,
    this.hideResultsUntilVoted = true,
    this.myChoice,
  });

  static const int minOptions = 2;
  static const int maxOptions = 5;

  final String question;
  final List<CommunityPollOption> options;

  /// true 면 투표해야 결과가 보인다. 작성자가 정한다.
  ///
  /// 기본값이 true 인 이유: 결과를 먼저 보여주면 앞선 표에 끌려가는 밴드왜건이
  /// 생겨 투표가 여론이 아니라 초반 몇 표의 증폭이 된다. 다만 "다들 어떻게
  /// 보세요" 류의 가벼운 투표에서는 결과가 곧 콘텐츠라, 작성자가 끌 수 있게 둔다.
  final bool hideResultsUntilVoted;

  /// 내가 고른 항목의 인덱스. null 이면 아직 투표 전.
  final int? myChoice;

  bool get voted => myChoice != null;

  /// 지금 결과(막대·퍼센트)를 보여줄지.
  bool get resultsVisible => voted || !hideResultsUntilVoted;

  int get totalVotes => options.fold(0, (sum, option) => sum + option.votes);

  /// [index] 항목의 득표 비율(0~1). 아무도 투표하지 않았으면 0.
  double ratio(int index) {
    final total = totalVotes;
    if (total == 0) return 0;
    return options[index].votes / total;
  }

  CommunityPoll vote(int index) {
    if (voted) return this;
    return CommunityPoll(
      question: question,
      options: [
        for (var i = 0; i < options.length; i++)
          i == index
              ? options[i].copyWith(votes: options[i].votes + 1)
              : options[i],
      ],
      hideResultsUntilVoted: hideResultsUntilVoted,
      myChoice: index,
    );
  }
}

class CommunityPollOption {
  const CommunityPollOption({required this.label, required this.votes});

  final String label;
  final int votes;

  CommunityPollOption copyWith({int? votes}) =>
      CommunityPollOption(label: label, votes: votes ?? this.votes);
}
