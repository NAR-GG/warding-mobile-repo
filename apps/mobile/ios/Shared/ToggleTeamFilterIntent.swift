import AppIntents
import WidgetKit

/// 위젯의 응원팀 필터를 켜고 끈다.
///
/// 앱을 열지 않고 위젯 안에서 처리한다(iOS 17+ `Button(intent:)`). 안드로이드의
/// 팀 버튼도 앱을 열지 않고 백그라운드로 토글하므로 동작이 맞는다.
///
/// 실제 조회는 [TodayMatchesFetcher] 가 한다 — 저장된 필터를 읽어 오늘 경기를
/// 다시 받아오고, 타임라인을 갱신하면 캘린더도 새 필터로 다시 그려진다.
@available(iOS 17.0, *)
struct ToggleTeamFilterIntent: AppIntent {

    static var title: LocalizedStringResource = "응원팀 필터 전환"
    static var description = IntentDescription("위젯에서 응원팀 경기만 볼지 전환합니다.")

    /// 앱을 열지 않는다.
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        guard let ud = UserDefaults(suiteName: TodayMatchesFetcher.appGroupId) else {
            return .result()
        }

        let next = !ud.bool(forKey: "team_selected")
        ud.set(next, forKey: "team_selected")
        // 아래 조회가 이 값을 곧바로 읽어야 한다. 같은 suite 라도 다른 인스턴스가
        // 열려 있으면 반영 전에 읽힐 수 있어 명시적으로 밀어 넣는다.
        ud.synchronize()

        // 토글 상태(로고 테두리)를 먼저 반영한다. 아래 조회가 늦거나 실행 시간
        // 제한에 걸려 잘려도, 누른 결과는 곧바로 보인다.
        WidgetCenter.shared.reloadAllTimelines()

        // 새 필터로 오늘 경기와 캘린더를 다시 받아온다.
        //
        // 위젯에서 토글하면 앱이 열리지 않으므로 캘린더를 갱신할 사람이 없다.
        // 오늘 경기만 받으면 격자는 옛 필터 그대로 남아 "필터가 안 먹는" 것처럼
        // 보인다 — 둘 다 받아야 한다.
        await withCheckedContinuation { continuation in
            TodayMatchesFetcher.refresh { _ in continuation.resume() }
        }
        await withCheckedContinuation { continuation in
            TodayMatchesFetcher.refreshCalendar { _ in continuation.resume() }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
