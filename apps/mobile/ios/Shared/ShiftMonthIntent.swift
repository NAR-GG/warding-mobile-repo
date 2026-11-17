import AppIntents
import WidgetKit

/// 위젯 캘린더의 월을 앞뒤로 옮긴다.
///
/// 앱을 열지 않고 위젯 안에서 처리한다(iOS 17+ `Button(intent:)`).
///
/// 예전에는 `Link` 로 딥링크를 열어 앱이 처리했는데, 앱이 뜨고 조회하고 위젯
/// 타임라인 리로드를 요청하기까지 12~16초가 걸렸다(로그 실측). 게다가 월을
/// 넘길 때마다 앱이 열렸다 닫혔다.
///
/// 여기서는 저장된 월만 먼저 옮겨 화면을 바꾸고, 그 달의 데이터를 이어서
/// 받아온다 — 안드로이드의 `WidgetMonthShiftReceiver` 와 같은 방식이다.
@available(iOS 17.0, *)
struct ShiftMonthIntent: AppIntent {

    static var title: LocalizedStringResource = "위젯 월 이동"
    static var description = IntentDescription("위젯 캘린더를 이전/다음 달로 옮깁니다.")

    /// 앱을 열지 않는다.
    static var openAppWhenRun: Bool = false

    /// 옮길 개월 수. -1 이면 이전 달, 1 이면 다음 달.
    @Parameter(title: "이동")
    var delta: Int

    init() {
        self.delta = 1
    }

    init(delta: Int) {
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        guard let ud = UserDefaults(suiteName: TodayMatchesFetcher.appGroupId) else {
            return .result()
        }

        // 저장된 월만 먼저 옮기고 격자는 비운다. 이전 달 대진이 새 달 격자에
        // 잘못 붙는 것을 막고, 화면은 곧바로 새 달을 보여준다.
        guard TodayMatchesFetcher.shiftStoredMonth(delta, in: ud) else {
            return .result()
        }
        WidgetCenter.shared.reloadAllTimelines()

        // 그 달의 데이터를 이어서 받아 채운다.
        await withCheckedContinuation { continuation in
            TodayMatchesFetcher.refreshCalendar { _ in continuation.resume() }
        }
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
