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
final class LiveActivityPlugin: NSObject {

    static let channelName = "com.warding.app/live_activity"

    /// 현재 앱에서 시작한 액티비티 (동시에 하나만 유지한다).
    private var currentActivityId: String?

    static func register(with messenger: FlutterBinaryMessenger) -> LiveActivityPlugin {
        let instance = LiveActivityPlugin()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak instance] call, result in
            instance?.handle(call, result: result)
        }
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

        // 로고는 App Group 에 파일로 캐싱하고 attributes 엔 파일명만 담는다.
        // (ActivityKit 4KB 페이로드 제한을 피해 원본 화질을 유지한다.)
        let logoA = cacheLogo(base64: args["teamALogoBase64"] as? String,
                              fileName: "teamA.png")
        let logoB = cacheLogo(base64: args["teamBLogoBase64"] as? String,
                              fileName: "teamB.png")

        let attributes = MatchLiveAttributes(
            matchId: args["matchId"] as? String ?? "",
            teamAName: args["teamAName"] as? String ?? "",
            teamACode: args["teamACode"] as? String ?? "",
            teamBName: args["teamBName"] as? String ?? "",
            teamBCode: args["teamBCode"] as? String ?? "",
            teamALogoFile: logoA,
            teamBLogoFile: logoB,
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
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
            currentActivityId = activity.id
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

    // MARK: - 헬퍼

    #if canImport(ActivityKit)
    /// Flutter 인자 맵 → ContentState 변환.
    @available(iOS 16.1, *)
    private func contentState(from args: [String: Any]) -> MatchLiveAttributes.ContentState {
        let phase = MatchLivePhase(
            rawValue: args["phase"] as? String ?? MatchLivePhase.playing.rawValue
        ) ?? .playing

        // 세트 시작 시각은 epoch millis 로 받는다.
        var startedAt: Date?
        if let millis = args["setStartedAtMillis"] as? NSNumber {
            startedAt = Date(timeIntervalSince1970: millis.doubleValue / 1000.0)
        }

        return MatchLiveAttributes.ContentState(
            phase: phase,
            setNumber: (args["setNumber"] as? NSNumber)?.intValue ?? 1,
            setStartedAt: startedAt,
            frozenTime: args["frozenTime"] as? String,
            scoreA: (args["scoreA"] as? NSNumber)?.intValue ?? 0,
            scoreB: (args["scoreB"] as? NSNumber)?.intValue ?? 0,
            statusLabel: args["statusLabel"] as? String ?? "",
            winnerTeamCode: args["winnerTeamCode"] as? String
        )
    }
    #endif

    /// base64 로고를 표시 크기로 리샘플링해 App Group 에 저장하고 파일명을 반환한다.
    ///
    /// 파일은 크기 제한이 없지만, 원본(2000×2000 등)을 그대로 두면 위젯이
    /// 매 렌더마다 큰 이미지를 디코딩한다. 표시 크기(40pt @3x = 120px)로
    /// 줄여 저장하되 PNG 라 투명 배경은 그대로 유지된다.
    private func cacheLogo(base64: String?, fileName: String) -> String? {
        guard let base64, !base64.isEmpty,
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
