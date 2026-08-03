import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// 실시간 경기 Live Activity 의 진행 상태.
///
/// Flutter 쪽 `LiveMatchPhase` 와 문자열 값을 맞춘다.
enum MatchLivePhase: String, Codable, Hashable {
    /// 세트 진행 중. LIVE 배지가 깜빡인다.
    case playing
    /// 세트 종료 (다음 세트 대기).
    case setEnded
    /// 경기(매치) 전체 종료.
    case matchEnded
}

#if canImport(ActivityKit)

/// 경기 Live Activity 의 정적 속성(액티비티 수명 동안 안 바뀌는 값) + 동적 상태.
///
/// 팀 로고는 Live Activity 확장에서 네트워크를 쓸 수 없어,
/// 앱이 미리 App Group 컨테이너에 PNG 로 캐싱한 파일명을 넘긴다.
/// (`MatchLiveImageStore` 참고)
@available(iOS 16.1, *)
struct MatchLiveAttributes: ActivityAttributes {

    /// 동적으로 갱신되는 상태값.
    struct ContentState: Codable, Hashable {
        /// 현재 진행 상태.
        var phase: MatchLivePhase

        /// 현재 세트 번호 (1부터).
        var setNumber: Int

        /// 세트 시작 시각. 경과 시간을 타이머로 자동 표시하는 데 쓴다.
        /// 세트가 끝났으면 nil 로 두고 [frozenTime] 을 쓴다.
        var setStartedAt: Date?

        /// 세트 종료/경기 종료 시 고정 표시할 경과 시간 문자열 (예: "32:14").
        var frozenTime: String?

        /// A팀(왼쪽) 세트 스코어.
        var scoreA: Int

        /// B팀(오른쪽) 세트 스코어.
        var scoreB: Int

        /// 상단 우측에 띄울 부가 라벨 (예: "LCK 서머 · 3세트 진행 중").
        var statusLabel: String

        /// 경기 종료 시 승리 팀 코드. 진행 중이면 nil.
        var winnerTeamCode: String?
    }

    /// 경기 ID (딥링크용).
    var matchId: String

    /// A팀(왼쪽) 표시명 / 코드.
    var teamAName: String
    var teamACode: String

    /// B팀(오른쪽) 표시명 / 코드.
    var teamBName: String
    var teamBCode: String

    /// App Group 컨테이너에 캐싱된 A팀 로고 파일명 (없으면 nil).
    ///
    /// ActivityKit 페이로드는 4KB 로 제한돼 이미지를 직접 실으면 화질을
    /// 크게 깎아야 한다. 파일은 크기 제한이 없어 원본 화질을 유지할 수 있다.
    /// 앱과 위젯 양쪽 entitlements 에 App Group 이 등록돼 있어야 한다.
    var teamALogoFile: String?

    /// App Group 컨테이너에 캐싱된 B팀 로고 파일명 (없으면 nil).
    var teamBLogoFile: String?

    /// 리그명 (예: "LCK").
    var leagueName: String

    /// 사용자가 응원하는 팀의 코드. 해당 팀 로고에 하트를 붙인다. 없으면 nil.
    var favoriteTeamCode: String?
}

#endif
