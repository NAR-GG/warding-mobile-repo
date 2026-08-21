import Foundation

/// 위젯이 앱 없이 오늘 경기를 직접 받아온다.
///
/// iOS 위젯은 안드로이드와 달리 Dart 콜백을 깨울 방법이 마땅치 않다
/// (`home_widget` 의 interactivity 콜백은 iOS 17+ 버튼 탭에만 걸리고, 타임라인
/// 갱신에는 걸리지 않는다). `WidgetCenter.reloadAllTimelines()` 도 저장된
/// UserDefaults 를 다시 그리라는 신호일 뿐 네트워크 조회를 하지 않는다.
/// 그래서 앱을 켜기 전까지 위젯 데이터가 영영 갱신되지 않았다.
///
/// 오늘 경기 엔드포인트(`/api/mobile/schedules`)는 인증이 필요 없으므로,
/// 여기서 직접 부르고 결과를 앱과 같은 형식으로 App Group 에 써 둔다.
/// 앱이 켜지면 Dart 쪽 `HomeWidgetService.refreshFromApi()` 가 같은 키를
/// 덮어쓰므로, 둘은 서로를 방해하지 않는다.
enum TodayMatchesFetcher {

    static let appGroupId = "group.com.warding.app"

    private static let host = "https://api.nar.kr"

    /// `league=ALL` 을 치환할 실제 리그 코드 전체.
    ///
    /// 이 엔드포인트는 일부 날짜에서 `league=ALL` 자체를 400 으로 거부하는
    /// 백엔드 버그가 있어, 앱(`ApiConfig.mobileSchedulesUrl`)과 똑같이 코드를
    /// 나열해 보낸다. 앱 쪽 목록이 바뀌면 여기도 같이 고쳐야 한다.
    private static let allRealLeagueCodes = [
        "LCK", "LPL", "LEC", "LCS", "MSI", "WORLDS",
        "EWC", "FIRST_STAND", "KESPA", "CBLOL", "LCP",
    ]

    /// 저장된 필터로 오늘 경기를 받아 App Group 에 쓴다.
    ///
    /// 성공하면 true. 실패해도 오늘 날짜로 빈 목록을 써 둔다 — 어제 저장분이
    /// 남으면 위젯이 그걸 stale 로 보고 "불러오는 중"에서 벗어나지 못한다.
    static func refresh(completion: @escaping (Bool) -> Void) {
        guard let ud = UserDefaults(suiteName: appGroupId) else {
            completion(false)
            return
        }

        let today = Date()
        let dateStr = dateKey(today)
        guard let url = schedulesURL(dateStr: dateStr, ud: ud) else {
            save(matches: [], date: today, to: ud)
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status),
                  let data = data,
                  let matches = parseMatches(data) else {
                save(matches: [], date: today, to: ud)
                completion(false)
                return
            }
            save(matches: matches, date: today, to: ud)
            completion(true)
        }.resume()
    }

    /// 저장된 달의 캘린더를 현재 필터로 다시 받아 App Group 에 쓴다.
    ///
    /// 위젯에서 필터를 바꾸면(응원팀 토글) 앱이 열리지 않으므로 캘린더를 갱신할
    /// 사람이 없다. 오늘 경기만 다시 받으면 격자는 옛 필터 그대로 남아 "필터가
    /// 안 먹는" 것처럼 보인다 — 그래서 여기서 함께 받아온다.
    static func refreshCalendar(completion: @escaping (Bool) -> Void) {
        guard let ud = UserDefaults(suiteName: appGroupId) else {
            completion(false)
            return
        }

        // 위젯이 보고 있는 달을 유지한다. 저장값이 없으면 이번 달.
        let month = storedMonth(ud) ?? monthKey(Date())

        var components = URLComponents(string: "\(host)/api/mobile/schedules/calendar")
        var items = [URLQueryItem(name: "month", value: month)]
        for league in effectiveLeagues(ud) {
            items.append(URLQueryItem(name: "league", value: league))
        }
        for teamId in savedTeamIds(ud) {
            items.append(URLQueryItem(name: "teamId", value: String(teamId)))
        }
        components?.queryItems = items

        guard let url = components?.url else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status),
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  // 응답 최상위 키는 `dates` 다 (ScheduleRepository._fetchCalendar 참고).
                  let days = json["dates"] as? [[String: Any]] else {
                completion(false)
                return
            }
            saveCalendar(month: month, days: days, to: ud)
            completion(true)
        }.resume()
    }

    /// 저장된 캘린더의 월만 [delta] 개월 옮기고 격자(`days`)는 비운다.
    ///
    /// 경기 칩을 그대로 두면 이전 달 대진이 새 달 격자에 잘못 붙는다. 비워 두면
    /// 날짜만 있는 달력이 보이고, [refreshCalendar] 가 채운다.
    ///
    /// @return 옮겼으면 true. 저장값이 없거나 파싱에 실패하면 false.
    @discardableResult
    static func shiftStoredMonth(_ delta: Int, in ud: UserDefaults) -> Bool {
        guard let current = storedMonth(ud) else { return false }
        let parts = current.split(separator: "-")
        guard parts.count >= 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else {
            return false
        }

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let base = Calendar.current.date(from: comps),
              let shifted = Calendar.current.date(byAdding: .month, value: delta, to: base) else {
            return false
        }

        let payload: [String: Any] = ["month": monthKey(shifted), "days": [String: Any]()]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return false
        }
        ud.set(jsonString, forKey: "calendar_data")
        ud.synchronize()
        return true
    }

    /// 앱이 저장한 캘린더에서 `yyyy-MM` 을 읽는다.
    private static func storedMonth(_ ud: UserDefaults) -> String? {
        guard let raw = ud.string(forKey: "calendar_data"),
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let month = json["month"] as? String,
              !month.isEmpty else {
            return nil
        }
        return month
    }

    private static func monthKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// 앱의 `HomeWidgetService.updateCalendar` 와 같은 형식으로 쓴다.
    private static func saveCalendar(month: String, days: [[String: Any]], to ud: UserDefaults) {
        var byDay: [String: [[String: String]]] = [:]
        for day in days {
            // 응답의 날짜는 `yyyy-MM-dd`. 앱은 '일'만 키로 쓴다.
            guard let dateStr = day["date"] as? String,
                  let dayNum = Int(dateStr.split(separator: "-").last.map(String.init) ?? "") else {
                continue
            }
            let matches = (day["matches"] as? [[String: Any]] ?? []).map { m in
                [
                    "blue": m["blueTeamCode"] as? String ?? "",
                    "red": m["redTeamCode"] as? String ?? "",
                    "display": m["displayText"] as? String ?? "",
                ]
            }
            byDay[String(dayNum)] = matches
        }

        let payload: [String: Any] = ["month": month, "days": byDay]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        ud.set(jsonString, forKey: "calendar_data")
    }

    // MARK: - URL

    private static func schedulesURL(dateStr: String, ud: UserDefaults) -> URL? {
        var components = URLComponents(string: "\(host)/api/mobile/schedules")
        var items = [URLQueryItem(name: "date", value: dateStr)]

        for league in effectiveLeagues(ud) {
            items.append(URLQueryItem(name: "league", value: league))
        }
        for teamId in savedTeamIds(ud) {
            items.append(URLQueryItem(name: "teamId", value: String(teamId)))
        }

        components?.queryItems = items
        return components?.url
    }

    /// 앱이 저장해 둔 리그 필터. 'ALL' 하나면 실제 코드 전체로 편다.
    ///
    /// `home_widget` 은 문자열만 저장하므로 앱이 JSON 배열 문자열로 넣어 둔다
    /// (`HomeWidgetService._saveWidgetFilters`).
    private static func effectiveLeagues(_ ud: UserDefaults) -> [String] {
        let saved = decodeJSONArray(ud.string(forKey: "widget_leagues")) as? [String] ?? []
        if saved.isEmpty { return allRealLeagueCodes }
        if saved.count == 1 && saved.first == "ALL" { return allRealLeagueCodes }
        return saved
    }

    /// 적용할 팀 필터.
    ///
    /// 앱 필터 화면에서 저장해 둔 `widget_team_ids` 를 바탕으로 하고, 응원팀
    /// 토글(`team_selected`)은 **자기 팀만** 더하거나 뺀다.
    ///
    /// 켤 때만 더하고 끌 때 아무것도 하지 않으면, 앱 필터에 그 팀이 들어 있을 때
    /// 토글을 꺼도 필터가 그대로 걸려 있다(안드로이드에서 같은 문제가 있었다).
    static func savedTeamIds(_ ud: UserDefaults) -> [Int] {
        var ids = decodeJSONArray(ud.string(forKey: "widget_team_ids")) as? [Int] ?? []
        let preferred = ud.integer(forKey: "preferred_team_id")
        guard preferred > 0 else { return ids }

        if ud.bool(forKey: "team_selected") {
            if !ids.contains(preferred) { ids.append(preferred) }
        } else {
            ids.removeAll { $0 == preferred }
        }
        return ids
    }

    private static func decodeJSONArray(_ raw: String?) -> [Any]? {
        guard let raw = raw, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [Any]
    }

    // MARK: - Parsing

    private static func parseMatches(_ data: Data) -> [[String: Any]]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = json["matches"] as? [[String: Any]] else {
            return nil
        }

        return raw.map { m in
            // 모바일 API 는 blueTeam/redTeam 키를 쓰고, 구 API 는 teamA/teamB 를
            // 쓴다 (앱의 ScheduleMatch.fromJson 과 동일하게 둘 다 받는다).
            let blue = (m["teamA"] ?? m["blueTeam"]) as? [String: Any] ?? [:]
            let red = (m["teamB"] ?? m["redTeam"]) as? [String: Any] ?? [:]
            let blueCode = blue["teamCode"] as? String ?? ""
            let redCode = red["teamCode"] as? String ?? ""

            return [
                "matchId": m["matchId"] as? String ?? "",
                "time": m["scheduledTime"] as? String ?? "",
                "status": m["matchStatus"] as? String ?? "",
                "blueCode": blueCode,
                "redCode": redCode,
                "display": "\(blueCode) VS \(redCode)",
            ]
        }
    }

    // MARK: - Save

    /// 앱의 `HomeWidgetService._saveTodayDetailed` 와 같은 형식으로 쓴다.
    private static func save(matches: [[String: Any]], date: Date, to ud: UserDefaults) {
        let payload: [String: Any] = [
            "date": dateKey(date),
            "weekday": mondayFirstWeekday(date),
            "matches": matches,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        ud.set(jsonString, forKey: "today_matches")
    }

    private static func dateKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Dart 의 `DateTime.weekday` 와 같은 월=1 ... 일=7 로 맞춘다
    /// (Foundation 은 일=1 ... 토=7).
    private static func mondayFirstWeekday(_ date: Date) -> Int {
        let sundayFirst = Calendar.current.component(.weekday, from: date)
        return sundayFirst == 1 ? 7 : sundayFirst - 1
    }
}
