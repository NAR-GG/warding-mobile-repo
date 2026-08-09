/// 실시간 경기 Live Activity 의 진행 국면.
///
/// 카드 자체는 서버가 APNs 로 만들고 갱신한다. 앱은 세트 목록에서 국면을
/// 판정해 "카드를 정리해도 되는 경기인지"를 판단할 때만 쓴다
/// (LiveMatchActivityController.resolvePhase).
enum LiveMatchPhase {
  /// 세트 진행 중.
  playing,

  /// 세트 종료 (다음 세트 대기).
  setEnded,

  /// 경기 전체 종료.
  matchEnded,
}
