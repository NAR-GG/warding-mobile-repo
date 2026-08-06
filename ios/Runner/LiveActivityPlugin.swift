import Flutter
import Foundation
import UIKit

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Flutter 에서 실시간 경기 Live Activity 를 제어하는 MethodChannel 핸들러.
///
/// 채널: `com.warding.app/live_activity`
/// - `isSupported` → Bool
/// - `start(payload)` → 액티비티 시작, activityId 반환
/// - `update(payload)` → 현재 액티비티 상태 갱신
/// - `end(payload)` → 액티비티 종료
/// - `endAll` → 남아있는 모든 경기 액티비티 종료
/// - `observePushToStartToken` → push-to-start 토큰 관찰 시작 (iOS 17.2+)
/// - `hasLogo(fileName)` → 로고 캐시 존재 여부
/// - `cacheLogo(base64, fileName)` → 로고를 App Group 에 미리 캐싱
final class LiveActivityPlugin: NSObject {

    static let channelName = "com.warding.app/live_activity"

    /// 현재 앱에서 시작한 액티비티 (동시에 하나만 유지한다).
    private var currentActivityId: String?

    /// 푸시 토큰을 Dart 쪽으로 되돌려 보낼 때 쓰는 채널.
    private var channel: FlutterMethodChannel?

    /// push-to-start 토큰 관찰 태스크. 중복 관찰을 막는다.
    private var pushToStartTask: Task<Void, Never>?

    static func register(with messenger: FlutterBinaryMessenger) -> LiveActivityPlugin {
        let instance = LiveActivityPlugin()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak instance] call, result in
            instance?.handle(call, result: result)
        }
        instance.channel = channel
        return instance
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(isSupported())
        case "start":
            start(args: call.arguments as? [String: Any] ?? [:], result: result)
        case "update":
            update(args: call.arguments as? [String: Any] ?? [:], result: result)
        case "end":
            end(args: call.arguments as? [String: Any] ?? [:], result: result)
        case "endAll":
            endAll(result: result)
        case "observePushToStartToken":
            observePushToStartToken(result: result)
        case "hasLogo":
            let args = call.arguments as? [String: Any] ?? [:]
            let fileName = args["fileName"] as? String ?? ""
            // URL 을 함께 주면 리브랜딩(같은 팀, 다른 이미지)까지 걸러낸다.
            if let url = args["url"] as? String, !url.isEmpty {
                result(MatchLiveImageStore.isCached(fileName: fileName, url: url))
            } else {
                result(MatchLiveImageStore.exists(fileName: fileName))
            }
        case "cacheLogo":
            let args = call.arguments as? [String: Any] ?? [:]
            let fileName = args["fileName"] as? String ?? ""
            let saved = cacheLogo(base64: args["base64"] as? String,
                                  fileName: fileName) != nil
            if saved, let url = args["url"] as? String {
                MatchLiveImageStore.rememberUrl(url, fileName: fileName)
            }
            result(saved)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - 지원 여부

    private func isSupported() -> Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }

    // MARK: - 시작

    private func start(args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else {
            result(FlutterError(code: "unsupported",
                                message: "Live Activity 는 iOS 16.1 이상에서만 지원됩니다.",
                                details: nil))
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            result(FlutterError(code: "disabled",
                                message: "설정에서 실시간 활동이 꺼져 있습니다.",
                                details: nil))
            return
        }

        // 이미 떠 있는 액티비티가 있으면 정리하고 새로 띄운다.
        endAllActivities()

        let teamACode = args["teamACode"] as? String ?? ""
        let teamBCode = args["teamBCode"] as? String ?? ""

        // 로고는 App Group 에 파일로 캐싱하고 attributes 엔 파일명만 담는다.
        // (ActivityKit 4KB 페이로드 제한을 피해 원본 화질을 유지한다.)
        //
        // 파일명은 서버와의 계약이라 `<팀코드>.png` 로 고정한다. 서버가
        // push-to-start 로 카드를 만들 때는 파일을 쓴 적이 없어 이름을 규칙으로
        // 맞춰야 하고, 여러 팀 로고를 미리 받아두려면 위치 기반(`teamA.png`)
        // 이름으로는 담을 수 없다.
        let logoA = cacheLogo(base64: args["teamALogoBase64"] as? String,
                              fileName: Self.logoFileName(for: teamACode))
        let logoB = cacheLogo(base64: args["teamBLogoBase64"] as? String,
                              fileName: Self.logoFileName(for: teamBCode))

        let attributes = MatchLiveAttributes(
            matchId: args["matchId"] as? String ?? "",
            teamAName: args["teamAName"] as? String ?? "",
            teamACode: teamACode,
            teamBName: args["teamBName"] as? String ?? "",
            teamBCode: teamBCode,
            // 이번 호출에서 저장에 실패해도 예전에 프리페치해 둔 파일이 있으면
            // 그걸 쓴다. 위젯은 파일이 없으면 로고 없이 그리므로 nil 도 안전하다.
            teamALogoFile: logoA ?? Self.cachedLogoFileName(for: teamACode),
            teamBLogoFile: logoB ?? Self.cachedLogoFileName(for: teamBCode),
            leagueName: args["leagueName"] as? String ?? "",
            favoriteTeamCode: args["favoriteTeamCode"] as? String
        )

        let state = contentState(from: args)

        do {
            let activity: Activity<MatchLiveAttributes>
            if #available(iOS 16.2, *) {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: .token
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: .token
                )
            }
            currentActivityId = activity.id
            observePushTokenUpdates(of: activity, matchId: attributes.matchId)
            result(activity.id)
        } catch {
            result(FlutterError(code: "start_failed",
                                message: error.localizedDescription,
                                details: nil))
        }
        #else
        result(FlutterError(code: "unsupported", message: "ActivityKit 없음", details: nil))
        #endif
    }

    // MARK: - 갱신

    private func update(args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else {
            result(false)
            return
        }
        let state = contentState(from: args)
        Task {
            for activity in Activity<MatchLiveAttributes>.activities {
                if #available(iOS 16.2, *) {
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                } else {
                    await activity.update(using: state)
                }
            }
            await MainActor.run { result(true) }
        }
        #else
        result(false)
        #endif
    }

    // MARK: - 종료

    private func end(args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else {
            result(false)
            return
        }
        let state = contentState(from: args)
        Task {
            for activity in Activity<MatchLiveAttributes>.activities {
                if #available(iOS 16.2, *) {
                    await activity.end(
                        ActivityContent(state: state, staleDate: nil),
                        dismissalPolicy: .default
                    )
                } else {
                    await activity.end(using: state, dismissalPolicy: .default)
                }
            }
            await MainActor.run {
                self.currentActivityId = nil
                result(true)
            }
        }
        #else
        result(false)
        #endif
    }

    private func endAll(result: @escaping FlutterResult) {
        endAllActivities()
        result(true)
    }

    private func endAllActivities() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        Task {
            for activity in Activity<MatchLiveAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        currentActivityId = nil
        #endif
    }

    // MARK: - push-to-start 토큰

    /// 앱 단위 push-to-start 토큰을 관찰해 Dart 로 넘긴다.
    ///
    /// 액티비티 토큰([observePushTokenUpdates])과 다른 값이다. 저건 이미 떠
    /// 있는 카드 하나를 가리키고, 이건 앱을 가리켜서 카드가 없어도 존재한다.
    /// 서버는 이 토큰이 있어야 앱이 안 떠 있는 상태에서 카드를 새로 만들 수 있다.
    ///
    /// iOS 17.2 미만은 발급되지 않는다 — 그 기기는 `scanForLiveMatch()` 폴백으로
    /// 포그라운드에서만 카드가 뜬다.
    private func observePushToStartToken(result: @escaping FlutterResult) {
        #if canImport(ActivityKit)
        guard #available(iOS 17.2, *) else {
            result(false)
            return
        }
        // 이미 관찰 중이면 스트림을 하나만 유지한다 — 앱 시작·포그라운드 복귀
        // 양쪽에서 불릴 수 있다.
        guard pushToStartTask == nil else {
            result(true)
            return
        }
        pushToStartTask = Task { [weak self] in
            for await tokenData in Activity<MatchLiveAttributes>.pushToStartTokenUpdates {
                let hexToken = tokenData.map { String(format: "%02x", $0) }.joined()
                await MainActor.run {
                    self?.channel?.invokeMethod("pushToStartToken", arguments: [
                        "pushToken": hexToken,
                    ])
                }
            }
        }
        result(true)
        #else
        result(false)
        #endif
    }

    #if canImport(ActivityKit)
    /// 액티비티의 APNs 푸시 토큰이 발급·갱신될 때마다 hex 문자열로 바꿔
    /// Dart 쪽에 알린다(`pushToken` 메서드). 서버가 이 토큰으로 카드를
    /// 직접 갱신한다 — 토큰 등록 자체는 인증(JWT)이 필요해 Dart 쪽에서 한다.
    @available(iOS 16.1, *)
    private func observePushTokenUpdates(of activity: Activity<MatchLiveAttributes>, matchId: String) {
        Task {
            for await tokenData in activity.pushTokenUpdates {
                let hexToken = tokenData.map { String(format: "%02x", $0) }.joined()
                await MainActor.run {
                    self.channel?.invokeMethod("pushToken", arguments: [
                        "matchId": matchId,
                        "pushToken": hexToken,
                    ])
                }
            }
        }
    }
    #endif

    // MARK: - 헬퍼

    #if canImport(ActivityKit)
    /// Flutter 인자 맵 → ContentState 변환.
    @available(iOS 16.1, *)
    private func contentState(from args: [String: Any]) -> MatchLiveAttributes.ContentState {
        let phase = MatchLivePhase(
            rawValue: args["phase"] as? String ?? MatchLivePhase.playing.rawValue
        ) ?? .playing

        return MatchLiveAttributes.ContentState(
            phase: phase,
            setNumber: (args["setNumber"] as? NSNumber)?.intValue ?? 1,
            scoreA: (args["scoreA"] as? NSNumber)?.intValue ?? 0,
            scoreB: (args["scoreB"] as? NSNumber)?.intValue ?? 0,
            statusLabel: args["statusLabel"] as? String ?? "",
            winnerTeamCode: args["winnerTeamCode"] as? String
        )
    }
    #endif

    /// 팀 코드에 대응하는 로고 파일명 (`T1.png`). 서버와 맞춘 규칙이다.
    /// 코드가 비면 저장할 이름이 없으므로 빈 문자열을 돌려준다.
    private static func logoFileName(for teamCode: String) -> String {
        teamCode.isEmpty ? "" : "\(teamCode).png"
    }

    /// 이미 캐싱돼 있는 팀 로고 파일명. 없으면 nil.
    private static func cachedLogoFileName(for teamCode: String) -> String? {
        let name = logoFileName(for: teamCode)
        return MatchLiveImageStore.exists(fileName: name) ? name : nil
    }

    /// base64 로고를 표시 크기로 리샘플링해 App Group 에 저장하고 파일명을 반환한다.
    ///
    /// 파일은 크기 제한이 없지만, 원본(2000×2000 등)을 그대로 두면 위젯이
    /// 매 렌더마다 큰 이미지를 디코딩한다. 표시 크기(40pt @3x = 120px)로
    /// 줄여 저장하되 PNG 라 투명 배경은 그대로 유지된다.
    private func cacheLogo(base64: String?, fileName: String) -> String? {
        guard !fileName.isEmpty,
              let base64, !base64.isEmpty,
              let raw = Data(base64Encoded: base64),
              let image = UIImage(data: raw) else { return nil }

        let target: CGFloat = 120
        let scale = min(target / max(image.size.width, 1),
                        target / max(image.size.height, 1), 1)
        let size = CGSize(width: image.size.width * scale,
                          height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let resized = UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }

        guard let data = resized.pngData() ?? image.pngData() else { return nil }
        return MatchLiveImageStore.save(data: data, fileName: fileName)
    }
}
