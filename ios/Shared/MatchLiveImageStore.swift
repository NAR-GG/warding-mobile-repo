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
        }
    }
}
