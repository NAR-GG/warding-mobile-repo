import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - 디자인 토큰 (시안 값 그대로)

/// Live Activity 시안 색상. 라이트/다크 두 벌을 명시적으로 들고 있다.
///
/// 잠금화면 Live Activity 는 별도 확장 타깃이라 앱의 `AppColors` 를
/// 참조할 수 없어 시안 hex 를 여기에 모아둔다.
private enum LiveColors {
    /// 카드 전체 배경 — rgba(255,255,255,0.7) / rgba(0,0,0,0.7)
    static func card(_ dark: Bool) -> Color {
        dark ? Color.black.opacity(0.7) : Color.white.opacity(0.7)
    }

    /// 상단 두 줄 배경 — #FFFFFF / #000000 (불투명)
    static func header(_ dark: Bool) -> Color {
        dark ? Color.black : Color.white
    }

    /// 스코어 줄 배경 — #FFFFFF 80% / #000000 80%
    static func scoreRow(_ dark: Bool) -> Color {
        dark ? Color.black.opacity(0.8) : Color.white.opacity(0.8)
    }

    /// 본문 텍스트 — #101113 / #FFFFFF
    static func text(_ dark: Bool) -> Color {
        dark ? Color.white : Color(red: 0x10 / 255, green: 0x11 / 255, blue: 0x13 / 255)
    }

    /// 스코어 숫자 — #909296 / #A6A7AB
    static func scoreText(_ dark: Bool) -> Color {
        dark
            ? Color(red: 0xA6 / 255, green: 0xA7 / 255, blue: 0xAB / 255)
            : Color(red: 0x90 / 255, green: 0x92 / 255, blue: 0x96 / 255)
    }

    /// 팀 로고 박스 배경 — 시안 #000000
    static let logoBox = Color.black

    /// 평점 유도 문구 — #25262B / #FCFDFE
    static func ratingText(_ dark: Bool) -> Color {
        dark
            ? Color(red: 0xFC / 255, green: 0xFD / 255, blue: 0xFE / 255)
            : Color(red: 0x25 / 255, green: 0x26 / 255, blue: 0x2B / 255)
    }

    /// 메인 그라디언트 (앱의 `AppColors.narBg` 와 같은 값).
    /// #E87558 0.76% → #C865C9 51.53% → #791BB8 100%
    static let mainGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0xE8 / 255, green: 0x75 / 255, blue: 0x58 / 255),
                  location: 0.0076),
            .init(color: Color(red: 0xC8 / 255, green: 0x65 / 255, blue: 0xC9 / 255),
                  location: 0.5153),
            .init(color: Color(red: 0x79 / 255, green: 0x1B / 255, blue: 0xB8 / 255),
                  location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // ── LIVE 배지 (라이트/다크 공통 — 시안이 동일) ──
    /// red/0
    static let liveBadgeBg = Color(red: 0xFF / 255, green: 0xF5 / 255, blue: 0xF5 / 255)
    /// red/3
    static let liveBadgeBorder = Color(red: 0xFF / 255, green: 0xA8 / 255, blue: 0xA8 / 255)
    /// red/8
    static let liveBadgeFg = Color(red: 0xE0 / 255, green: 0x31 / 255, blue: 0x31 / 255)

    /// 종료 상태 배지 — LIVE 배지와 같은 형태의 중립 톤.
    static func endedBadgeBg(_ dark: Bool) -> Color {
        dark
            ? Color(red: 0x25 / 255, green: 0x26 / 255, blue: 0x2B / 255)
            : Color(red: 0xF1 / 255, green: 0xF3 / 255, blue: 0xF5 / 255)
    }

    static func endedBadgeFg(_ dark: Bool) -> Color {
        dark
            ? Color(red: 0xA6 / 255, green: 0xA7 / 255, blue: 0xAB / 255)
            : Color(red: 0x90 / 255, green: 0x92 / 255, blue: 0x96 / 255)
    }
}

/// 시안 레이아웃 수치. 기준 폭 371 에서 화면 폭에 맞춰 비율로 스케일한다.
private enum LiveMetrics {
    /// 시안 기준 카드 폭.
    static let baseWidth: CGFloat = 371

    static let cardHeight: CGFloat = 153
    static let cornerRadius: CGFloat = 21

    /// 1단(로고 + LIVE 배지), 2단(세트 + 시간), 3단(스코어) 높이.
    static let logoRowHeight: CGFloat = 30
    static let infoRowHeight: CGFloat = 30
    static let scoreRowHeight: CGFloat = 93

    /// 경기 종료 4단(리그명 + 평점 남기기) — 2단이 빠진 자리를 대신한다.
    /// 상단 그라디언트 보더 3 + 상하 패딩 4 + 내용 18 + 하단 여백.
    static let footerBorder: CGFloat = 3

    /// 헤더 로고 69×14.
    static let logoWidth: CGFloat = 69
    static let logoHeight: CGFloat = 14

    /// LIVE 배지 46×18.
    static let badgeWidth: CGFloat = 46
    static let badgeHeight: CGFloat = 18

    /// 팀 칼럼 68×70, 로고 박스 50×50, 로고 이미지 40×40.
    static let teamColumnWidth: CGFloat = 68
    static let teamColumnHeight: CGFloat = 70
    static let teamLogoBox: CGFloat = 50
    static let teamLogoImage: CGFloat = 40

    /// 스코어 박스 116×77, 팀 칼럼과의 간격 24.
    static let scoreBoxWidth: CGFloat = 116
    static let scoreBoxHeight: CGFloat = 77
    static let contentGap: CGFloat = 24
}

// MARK: - 공용 서브뷰

/// 헤더 좌측 Warding 로고 (69×14).
///
/// 에셋은 라이트용(검정) 한 벌만 두고 템플릿 렌더링으로 다크 모드 색을 맞춘다.
@available(iOS 16.1, *)
private struct WardingLogo: View {
    let isDark: Bool
    let scale: CGFloat

    var body: some View {
        Image("warding-logo-light")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(
                width: LiveMetrics.logoWidth * scale,
                height: LiveMetrics.logoHeight * scale
            )
            .foregroundColor(LiveColors.text(isDark))
    }
}

/// 헤더 우측 LIVE 배지 (46×18). 진행 중이면 점이 깜빡인다.
@available(iOS 16.1, *)
private struct LiveBadge: View {
    let phase: MatchLivePhase
    let isDark: Bool
    let scale: CGFloat

    private var isLive: Bool { phase == .playing }

    private var label: String {
        switch phase {
        case .playing: return "LIVE"
        case .setEnded: return "SET END"
        case .matchEnded: return "END"
        }
    }

    private var foreground: Color {
        isLive ? LiveColors.liveBadgeFg : LiveColors.endedBadgeFg(isDark)
    }

    private var background: Color {
        isLive ? LiveColors.liveBadgeBg : LiveColors.endedBadgeBg(isDark)
    }

    var body: some View {
        HStack(spacing: 6 * scale) {
            if isLive {
                LiveDot(scale: scale)
            }
            Text(label)
                .font(.system(size: 8 * scale, weight: .medium))
                .foregroundColor(foreground)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 8 * scale)
        .padding(.vertical, 4 * scale)
        .frame(height: LiveMetrics.badgeHeight * scale)
        .background(
            RoundedRectangle(cornerRadius: 10 * scale)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * scale)
                        .stroke(
                            isLive ? LiveColors.liveBadgeBorder : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }
}

/// LIVE 배지의 빨간 점.
///
/// 잠금화면 Live Activity 는 렌더된 스냅샷을 띄우는 구조라 깜빡임이
/// 안정적으로 반영되지 않는다. 주기적으로 다시 그리는 대신 정적으로 둔다.
@available(iOS 16.1, *)
private struct LiveDot: View {
    let scale: CGFloat

    var body: some View {
        Circle()
            .fill(LiveColors.liveBadgeFg)
            .frame(width: 6 * scale, height: 6 * scale)
    }
}

/// 팀 칼럼 (68×70) — 검은 박스(50×50) 안에 팀 로고(40×40), 2 간격 아래 팀명.
@available(iOS 16.1, *)
private struct TeamColumn: View {
    let name: String
    let logo: UIImage?
    let isDark: Bool
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 2 * scale) {
            ZStack {
                RoundedRectangle(cornerRadius: 10 * scale)
                    .fill(LiveColors.logoBox)

                if let logo {
                    Image(uiImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: LiveMetrics.teamLogoImage * scale,
                            height: LiveMetrics.teamLogoImage * scale
                        )
                } else {
                    // 로고 프리페치 전에도 어느 팀인지 읽히게 이름을 대신 그린다.
                    Text(name)
                        .font(.system(size: 14 * scale, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4 * scale)
                }
            }
            .frame(
                width: LiveMetrics.teamLogoBox * scale,
                height: LiveMetrics.teamLogoBox * scale
            )

            Text(name)
                .font(.system(size: 13 * scale, weight: .medium))
                .foregroundColor(LiveColors.text(isDark))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: LiveMetrics.teamColumnWidth * scale)
        }
        .frame(
            width: LiveMetrics.teamColumnWidth * scale,
            height: LiveMetrics.teamColumnHeight * scale
        )
    }
}

/// 팀 로고 박스 단독 (50×50, 안에 로고 40×40).
///
/// 세트 종료 화면에서 팀명 없이 로고만 나란히 놓을 때 쓴다.
/// 응원 팀이면 우측 하단 모서리에 하트(13×11)를 붙인다.
@available(iOS 16.1, *)
private struct TeamLogoBox: View {
    let logo: UIImage?
    let teamCode: String
    let isFavorite: Bool
    let scale: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10 * scale)
                .fill(LiveColors.logoBox)

            if let logo {
                Image(uiImage: logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: LiveMetrics.teamLogoImage * scale,
                        height: LiveMetrics.teamLogoImage * scale
                    )
            } else {
                // 서버가 만든 카드는 로고 프리페치가 끝나기 전에 뜰 수 있다.
                // 그때 빈 검은 박스만 남지 않도록 팀 코드를 대신 그린다.
                Text(teamCode)
                    .font(.system(size: 14 * scale, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 4 * scale)
            }
        }
        .frame(
            width: LiveMetrics.teamLogoBox * scale,
            height: LiveMetrics.teamLogoBox * scale
        )
        .overlay(alignment: .bottomTrailing) {
            if isFavorite {
                Image("heart")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13 * scale, height: 11 * scale)
                    // 모서리에 걸치도록 살짝 바깥으로 뺀다.
                    .offset(x: 3 * scale, y: 2 * scale)
            }
        }
    }
}

/// 가운데 스코어 박스 (116×77).
@available(iOS 16.1, *)
private struct ScoreBox: View {
    let scoreA: Int
    let scoreB: Int
    let isDark: Bool
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 14 * scale) {
            digit("\(scoreA)")
            digit(":")
            digit("\(scoreB)")
        }
        .padding(.vertical, 14 * scale)
        .frame(width: LiveMetrics.scoreBoxWidth * scale)
    }

    private func digit(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 36 * scale, weight: .bold))
            .monospacedDigit()
            .foregroundColor(LiveColors.scoreText(isDark))
    }
}

// MARK: - 잠금화면 카드 본체

@available(iOS 16.1, *)
private struct MatchLiveLockScreenView: View {
    let attributes: MatchLiveAttributes
    let state: MatchLiveAttributes.ContentState

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        // 잠금화면 Live Activity 는 시스템이 폭을 정해 주고, 그 폭에 맞춰
        // 크기를 협상한다. GeometryReader 를 쓰면 이 협상이 깨져 내용이
        // 0 으로 접히므로 시안 수치를 그대로 쓴다(스케일 1).
        // 각 행이 자기 배경(헤더 #FFF, 스코어 #FFF 80%)을 갖는다. 여기서
        // 카드 배경을 또 깔면 두 겹이 겹쳐 스코어 줄의 투명도가 죽는다.
        // 카드 전체는 경기 상세로, 안쪽 '평점 남기기' 줄만 선수 평점 탭으로
        // 간다. 바깥을 Link 로 감싸야 내부 Link 가 우선 적용된다
        // (widgetURL 을 쓰면 카드 전체를 덮어 내부 Link 가 무시된다).
        Link(destination: detailURL) {
            VStack(spacing: 0) {
                logoRow(scale: 1)
                // 경기 종료는 세트/시간 줄 대신 하단 평점 유도 줄을 쓴다.
                if state.phase != .matchEnded {
                    infoRow(scale: 1)
                }
                scoreRow(scale: 1)
                if state.phase == .matchEnded {
                    matchEndedFooter(scale: 1)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// 1단 — 좌: Warding 로고, 우: LIVE 배지(진행 중) 또는 "SET n 종료"(종료).
    private func logoRow(scale: CGFloat) -> some View {
        HStack(spacing: 10 * scale) {
            WardingLogo(isDark: isDark, scale: scale)
            Spacer(minLength: 0)
            if state.phase == .playing {
                LiveBadge(phase: state.phase, isDark: isDark, scale: scale)
            } else {
                Text(endedLabel)
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundColor(LiveColors.text(isDark))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20 * scale)
        .padding(.top, 8 * scale)
        .padding(.bottom, 6 * scale)
        .frame(height: LiveMetrics.logoRowHeight * scale)
        .background(LiveColors.header(isDark))
    }

    /// 종료 상태에서 1단 우측에 띄울 라벨.
    private var endedLabel: String {
        switch state.phase {
        case .matchEnded:
            return "\(attributes.teamACode) VS \(attributes.teamBCode)"
                + " 마지막 세트가 종료됐습니다."
        default:
            return "SET \(state.setNumber) 종료"
        }
    }

    /// 경기 종료 4단 — 상단 그라디언트 보더 + 리그명 / "SET n 평점 남기기".
    private func matchEndedFooter(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            // inside border-top 3px — 메인 그라디언트.
            LiveColors.mainGradient
                .frame(height: LiveMetrics.footerBorder * scale)

            HStack(spacing: 0) {
                Text(attributes.leagueName)
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundColor(LiveColors.text(isDark))
                    .opacity(0.7)
                    .lineLimit(1)

                Spacer(minLength: 8 * scale)

                Link(destination: ratingURL) {
                    HStack(spacing: 0) {
                        Text("SET \(state.setNumber) 평점 남기기")
                            .font(.system(size: 13 * scale, weight: .medium))
                            .foregroundColor(LiveColors.text(isDark))
                            .lineLimit(1)
                        Image("live-right")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24 * scale, height: 24 * scale)
                            .foregroundColor(LiveColors.text(isDark))
                    }
                }
            }
            .padding(.horizontal, 20 * scale)
            .padding(.vertical, 4 * scale)
        }
        .background(LiveColors.scoreRow(isDark))
    }

    /// 경기 상세(기본 탭) 딥링크 — 카드의 평점 줄 외 영역이 쓴다.
    private var detailURL: URL {
        URL(string: "warding://match/\(attributes.matchId)")!
    }

    /// '평점 남기기' 딥링크 — 경기 상세의 선수 평점 탭을 해당 세트로 연다.
    private var ratingURL: URL {
        URL(string: "warding://match/\(attributes.matchId)"
            + "?tab=rating&set=\(state.setNumber)") ?? detailURL
    }


    /// 2단 — 진행 중이면 "SET 1 - 12:24" + 리그명,
    /// 세트 종료면 "SET 1이 종료되었습니다. SET 2 준비 중입니다." (30px).
    @ViewBuilder
    private func infoRow(scale: CGFloat) -> some View {
        Group {
            if state.phase == .setEnded {
                nextSetNotice(scale: scale)
            } else {
                HStack(spacing: 41 * scale) {
                    setAndElapsedView(scale: scale)
                    Spacer(minLength: 0)
                    Text(attributes.leagueName)
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundColor(LiveColors.text(isDark))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(.horizontal, 20 * scale)
        .padding(.top, 4 * scale)
        .padding(.bottom, 8 * scale)
        .frame(height: LiveMetrics.infoRowHeight * scale)
        .background(LiveColors.header(isDark))
    }

    /// 세트 종료 안내 — 다음 세트 표기만 메인 그라디언트로 강조한다.
    private func nextSetNotice(scale: CGFloat) -> some View {
        let font = Font.system(size: 13 * scale, weight: .medium)
        return HStack(spacing: 0) {
            Text("SET \(state.setNumber)이 종료되었습니다. ")
                .font(font)
                .foregroundColor(LiveColors.text(isDark))
            Text("SET \(state.setNumber + 1)")
                .font(font)
                .foregroundStyle(LiveColors.mainGradient)
            Text(" 준비 중입니다.")
                .font(font)
                .foregroundColor(LiveColors.text(isDark))
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// 3단 — 진행 중이면 팀·스코어·팀, 세트 종료면 평점 유도 + 팀 로고 (93px).
    @ViewBuilder
    private func scoreRow(scale: CGFloat) -> some View {
        Group {
            if state.phase == .setEnded {
                ratingRow(scale: scale)
            } else {
                playingScoreRow(scale: scale)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: LiveMetrics.scoreRowHeight * scale, alignment: .bottom)
        // 경기 종료는 스코어 줄이 불투명(#FFF), 그 아래 4단이 80% 를 맡는다.
        .background(
            state.phase == .matchEnded
                ? LiveColors.header(isDark)
                : LiveColors.scoreRow(isDark)
        )
    }

    /// 진행 중 3단 — 팀 · 스코어 · 팀.
    ///
    /// 시안의 `con` 컨테이너는 `align-items: flex-end` 라 세 칼럼이 바닥
    /// 기준으로 정렬된다. 스코어 박스(77)가 팀 칼럼(70)보다 커서 아래로 더 내려온다.
    private func playingScoreRow(scale: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: LiveMetrics.contentGap * scale) {
            TeamColumn(
                name: attributes.teamAName,
                logo: MatchLiveImageStore.load(fileName: attributes.teamALogoFile),
                isDark: isDark,
                scale: scale
            )
            ScoreBox(
                scoreA: state.scoreA,
                scoreB: state.scoreB,
                isDark: isDark,
                scale: scale
            )
            TeamColumn(
                name: attributes.teamBName,
                logo: MatchLiveImageStore.load(fileName: attributes.teamBLogoFile),
                isDark: isDark,
                scale: scale
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14 * scale)
        .padding(.top, 6 * scale)
        .padding(.bottom, 10 * scale)
    }

    /// 세트 종료 3단 — 좌: 리그·대진·평점 유도, 우: 양 팀 로고.
    private func ratingRow(scale: CGFloat) -> some View {
        HStack(spacing: 4 * scale) {
            ratingPrompt(scale: scale)
            Spacer(minLength: 0)
            teamLogos(scale: scale)
        }
        .padding(.top, 12 * scale)
        .padding(.leading, 14 * scale)
        .padding(.trailing, 14 * scale)
        .padding(.bottom, 14 * scale)
    }

    /// 좌측 — 리그명 / "A VS B  어떠셨나요?" / 별 + "SET n 평점 남기기" + 화살표.
    private func ratingPrompt(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(attributes.leagueName)
                .font(.system(size: 13 * scale, weight: .medium))
                .foregroundColor(LiveColors.text(isDark))
                .lineLimit(1)

            HStack(spacing: 4 * scale) {
                Text("\(attributes.teamACode) VS \(attributes.teamBCode)")
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundColor(LiveColors.text(isDark))
                Text("어떠셨나요?")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundColor(LiveColors.text(isDark))
            }
            .lineLimit(1)

            // 이 줄만 선수 평점 탭으로 간다. 카드의 나머지 영역은 바깥
            // `Link`(경기 상세 기본 탭)가 받는다.
            Link(destination: ratingURL) {
                HStack(spacing: 4 * scale) {
                    // 별은 라이트/다크 모두 에셋 원본 색(흰색)을 그대로 쓴다.
                    Image("live-stars")
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: 24 * scale, height: 24 * scale)
                    Text("SET \(state.setNumber) 평점 남기기")
                        .font(.system(size: 14 * scale, weight: .medium))
                        .foregroundColor(LiveColors.ratingText(isDark))
                        .lineLimit(1)
                    Image("live-right")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24 * scale, height: 24 * scale)
                        .foregroundColor(LiveColors.ratingText(isDark))
                }
            }
        }
    }

    /// 우측 — 양 팀 로고 박스(50×50)를 9 간격으로 나란히.
    private func teamLogos(scale: CGFloat) -> some View {
        HStack(spacing: 9 * scale) {
            TeamLogoBox(
                logo: MatchLiveImageStore.load(fileName: attributes.teamALogoFile),
                teamCode: attributes.teamACode,
                isFavorite: attributes.favoriteTeamCode == attributes.teamACode,
                scale: scale
            )
            TeamLogoBox(
                logo: MatchLiveImageStore.load(fileName: attributes.teamBLogoFile),
                teamCode: attributes.teamBCode,
                isFavorite: attributes.favoriteTeamCode == attributes.teamBCode,
                scale: scale
            )
        }
        .padding(.horizontal, 9 * scale)
    }

    /// 2단 좌측 — "SET 1" 형태의 세트 번호.
    ///
    /// 경과 시간은 서버 푸시로만 카드를 갱신하는 구조로 바뀌면서 더는
    /// 표시하지 않는다(자세한 배경은 `LiveMatchActivityState` 주석 참고).
    private func setAndElapsedView(scale: CGFloat) -> some View {
        Text("SET \(state.setNumber)")
            .font(.system(size: 13 * scale, weight: .medium))
            .foregroundColor(LiveColors.text(isDark))
    }
}

// MARK: - Dynamic Island

@available(iOS 16.1, *)
private struct CompactTeam: View {
    let logoFile: String?
    let score: Int
    let leadingLogo: Bool

    var body: some View {
        HStack(spacing: 3) {
            if leadingLogo { logo }
            Text("\(score)")
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
            if !leadingLogo { logo }
        }
    }

    @ViewBuilder
    private var logo: some View {
        if let image = MatchLiveImageStore.load(fileName: logoFile) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
        }
    }
}

/// Dynamic Island 확장 영역용 축소 팀 표시.
@available(iOS 16.1, *)
private struct ExpandedTeam: View {
    let name: String
    let logoFile: String?

    var body: some View {
        VStack(spacing: 2) {
            if let image = MatchLiveImageStore.load(fileName: logoFile) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            }
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 60)
    }
}

// MARK: - Widget 선언

@available(iOS 16.1, *)
struct MatchLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchLiveAttributes.self) { context in
            MatchLiveLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            // widgetURL 은 쓰지 않는다 — 카드 전체를 덮어 내부 Link(평점 줄)가
            // 무시되기 때문이다. 링크는 뷰 안에서 영역별로 건다.
            // 시스템 기본 배경을 걷어내야 각 행의 반투명(#FFF 80%)이 잠금화면
            // 배경 위에서 제대로 비친다. nil 을 주면 시스템이 자체 배경을 깔아
            // 그 위에 얹힌 반투명이 불투명하게 보인다.
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedTeam(
                        name: context.attributes.teamAName,
                        logoFile: context.attributes.teamALogoFile
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTeam(
                        name: context.attributes.teamBName,
                        logoFile: context.attributes.teamBLogoFile
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("\(context.state.scoreA) : \(context.state.scoreB)")
                            .font(.system(size: 24, weight: .bold))
                            .monospacedDigit()
                        Text(context.state.phase == .playing
                            ? "SET \(context.state.setNumber)"
                            : context.state.statusLabel)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                CompactTeam(
                    logoFile: context.attributes.teamALogoFile,
                    score: context.state.scoreA,
                    leadingLogo: true
                )
            } compactTrailing: {
                CompactTeam(
                    logoFile: context.attributes.teamBLogoFile,
                    score: context.state.scoreB,
                    leadingLogo: false
                )
            } minimal: {
                Text("\(context.state.scoreA):\(context.state.scoreB)")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
            }
            .widgetURL(URL(string: "warding://match/\(context.attributes.matchId)"))
        }
    }
}
