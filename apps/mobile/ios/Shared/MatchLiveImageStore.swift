import Foundation
import UIKit

/// Live Activity 확장에서 쓸 팀 로고를 App Group 컨테이너에 캐싱한다.
///
/// Live Activity(위젯 확장)는 네트워크 요청이 사실상 불가하므로,
/// 앱이 액티비티를 시작하기 전에 로고를 내려받아 여기 저장해두고
/// 확장은 파일명만 받아 디스크에서 읽는다.
enum MatchLiveImageStore {

    /// Runner / WidgetExtension 양쪽 entitlements 에 등록된 App Group.
    static let appGroupId = "group.com.warding.app"

    /// 로고를 담아둘 하위 디렉터리명.
    private static let folderName = "LiveActivityLogos"

    /// App Group 컨테이너의 로고 디렉터리 URL. 없으면 만든다.
    private static var folderUrl: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        else {
            // entitlements 에 App Group 이 없으면 여기로 온다. 이 경우 로고가
            // 조용히 사라지므로(빈 검은 박스) 원인을 남긴다.
            NSLog("[MatchLiveImageStore] App Group '\(appGroupId)' 컨테이너 접근 실패 "
                  + "— 타깃 entitlements 확인 필요")
            return nil
        }
        let dir = container.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true
            )
        }
        return dir
    }

    /// PNG 데이터를 [fileName] 으로 저장하고 파일명을 돌려준다. 실패 시 nil.
    @discardableResult
    static func save(data: Data, fileName: String) -> String? {
        guard let dir = folderUrl else { return nil }
        let url = dir.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    /// [fileName] 로고가 이미 캐싱돼 있는지. 없으면 false.
    ///
    /// 프리페치가 매번 다시 내려받지 않도록 존재 확인만 한다 —
    /// [load] 로 대신하면 쓰지도 않을 이미지를 디코딩하게 된다.
    static func exists(fileName: String) -> Bool {
        guard !fileName.isEmpty, let dir = folderUrl else { return false }
        return FileManager.default.fileExists(
            atPath: dir.appendingPathComponent(fileName).path
        )
    }

    /// 캐싱한 로고의 원본 URL 을 담아두는 App Group UserDefaults.
    ///
    /// 파일이 있어도 URL 이 바뀌었으면 다시 받아야 리브랜딩이 반영된다.
    /// 파일과 같은 컨테이너에 둬야 둘이 함께 살고 함께 지워진다.
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private static func urlKey(_ fileName: String) -> String {
        "logo_url_\(fileName)"
    }

    /// [fileName] 이 [url] 로 받아둔 그대로 남아 있는지.
    ///
    /// 파일 존재와 URL 일치를 함께 본다 — 둘 중 하나만 맞으면 다시 받아야 한다.
    static func isCached(fileName: String, url: String) -> Bool {
        guard !url.isEmpty, exists(fileName: fileName) else { return false }
        return defaults?.string(forKey: urlKey(fileName)) == url
    }

    /// [fileName] 을 받아온 원본 [url] 을 기록한다.
    static func rememberUrl(_ url: String, fileName: String) {
        guard !fileName.isEmpty, !url.isEmpty else { return }
        defaults?.set(url, forKey: urlKey(fileName))
    }

    /// 저장된 [fileName] 로고를 읽어 UIImage 로 반환한다. 없으면 nil.
    static func load(fileName: String?) -> UIImage? {
        guard let fileName, !fileName.isEmpty,
              let dir = folderUrl else { return nil }
        let url = dir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// 캐싱된 로고를 전부 지운다 (경기 종료 후 정리용).
    static func clear() {
        guard let dir = folderUrl,
              let files = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: nil
              ) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
            // URL 기록도 함께 지운다 — 파일만 지우면 "받아둔 URL 그대로"로
            // 잘못 판정해 다시 받지 않는다.
            defaults?.removeObject(forKey: urlKey(file.lastPathComponent))
        }
    }
}
