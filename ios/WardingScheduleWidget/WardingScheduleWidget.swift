import WidgetKit
import SwiftUI
import UIKit

// MARK: - Data Models

struct CalendarData {
    let month: String
    let year: Int
    let monthNum: Int
    let days: [Int: [MatchBrief]]

    static let empty = CalendarData(
        month: "",
        year: Calendar.current.component(.year, from: Date()),
        monthNum: Calendar.current.component(.month, from: Date()),
        days: [:]
    )
}

struct MatchBrief {
    let blue: String
    let red: String
    let display: String
}

struct TodayData {
    let dateStr: String
    let weekday: Int // 1=Mon ... 7=Sun
    let matches: [TodayMatch]

    static let empty = TodayData(dateStr: "", weekday: 1, matches: [])
}

struct TodayMatch {
    let matchId: String
    let time: String       // "15:00" 등
    let status: String     // "FINISHED", "LIVE", "SCHEDULED" 등
    let blueCode: String
    let redCode: String
    let display: String

    var isFinished: Bool {
        status == "FINISHED" || status == "COMPLETED" || status == "completed"
    }
    var isLive: Bool { status == "LIVE" || status == "IN_PROGRESS" }
}

// MARK: - Timeline Provider

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), calendar: .empty, today: .empty, teamImageUrl: nil, teamImage: nil, hasFilter: false, teamSelected: false, teamCode: "", sundayFirst: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let (cal, today, teamUrl, hasFilter, teamSelected, teamCode, sundayFirst) = loadData()
        downloadTeamImage(url: teamUrl) { image in
            completion(ScheduleEntry(date: Date(), calendar: cal, today: today, teamImageUrl: teamUrl, teamImage: image, hasFilter: hasFilter, teamSelected: teamSelected, teamCode: teamCode, sundayFirst: sundayFirst))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let (cal, today, teamUrl, hasFilter, teamSelected, teamCode, sundayFirst) = loadData()
        downloadTeamImage(url: teamUrl) { image in
            let entry = ScheduleEntry(date: Date(), calendar: cal, today: today, teamImageUrl: teamUrl, teamImage: image, hasFilter: hasFilter, teamSelected: teamSelected, teamCode: teamCode, sundayFirst: sundayFirst)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func downloadTeamImage(url: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlStr = url, let imageUrl = URL(string: urlStr) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: imageUrl) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }.resume()
    }

    private func loadData() -> (CalendarData, TodayData, String?, Bool, Bool, String, Bool) {
        guard let ud = UserDefaults(suiteName: "group.com.warding.app") else {
            return (.empty, .empty, nil, false, false, "", false)
        }
        let teamUrl = ud.string(forKey: "team_image_url")
        let hasFilter = ud.bool(forKey: "has_filter")
        let teamSelected = ud.bool(forKey: "team_selected")
        let teamCode = ud.string(forKey: "team_code") ?? ""
        let sundayFirst = ud.string(forKey: "week_start") == "sunday"
        return (loadCalendar(ud), loadToday(ud), teamUrl, hasFilter, teamSelected, teamCode, sundayFirst)
    }

    private func loadCalendar(_ ud: UserDefaults) -> CalendarData {
        guard let jsonString = ud.string(forKey: "calendar_data"),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let month = json["month"] as? String,
              let daysDict = json["days"] as? [String: Any] else {
            return .empty
        }

        let parts = month.split(separator: "-")
        let year = Int(parts[0]) ?? Calendar.current.component(.year, from: Date())
        let monthNum = Int(parts[1]) ?? Calendar.current.component(.month, from: Date())

        var days: [Int: [MatchBrief]] = [:]
        for (dayStr, matches) in daysDict {
            guard let day = Int(dayStr),
                  let matchList = matches as? [[String: Any]] else { continue }
            days[day] = matchList.map { m in
                MatchBrief(
                    blue: m["blue"] as? String ?? "",
                    red: m["red"] as? String ?? "",
                    display: m["display"] as? String ?? ""
                )
            }
        }
        return CalendarData(month: month, year: year, monthNum: monthNum, days: days)
    }

    private func loadToday(_ ud: UserDefaults) -> TodayData {
        guard let jsonString = ud.string(forKey: "today_matches"),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty
        }

        let dateStr = json["date"] as? String ?? ""
        let weekday = json["weekday"] as? Int ?? 1
        let matchArr = json["matches"] as? [[String: Any]] ?? []

        let matches = matchArr.map { m in
            TodayMatch(
                matchId: m["matchId"] as? String ?? "",
                time: m["time"] as? String ?? "",
                status: m["status"] as? String ?? "",
                blueCode: m["blueCode"] as? String ?? "",
                redCode: m["redCode"] as? String ?? "",
                display: m["display"] as? String ?? ""
            )
        }
        return TodayData(dateStr: dateStr, weekday: weekday, matches: matches)
    }
}

// MARK: - Timeline Entry

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let calendar: CalendarData
    let today: TodayData
    let teamImageUrl: String?
    let teamImage: UIImage?
    let hasFilter: Bool
    let teamSelected: Bool
    let teamCode: String
    let sundayFirst: Bool
}

// MARK: - Week-start-aware calendar helpers

/// [year]년 [month]월 1일이 그리드에서 몇 번째 칸(0-based)에 오는지.
/// [sundayFirst] 가 false면 월요일 시작(0=월 ... 6=일), true면 일요일 시작(0=일 ... 6=토).
func firstWeekdayIndex(year: Int, month: Int, sundayFirst: Bool) -> Int {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = 1
    let date = Calendar.current.date(from: comps) ?? Date()
    let wd = Calendar.current.component(.weekday, from: date) // Sun=1 ... Sat=7
    return sundayFirst ? (wd - 1) : ((wd + 5) % 7)
}

/// [sundayFirst] 기준으로 정렬된 요일 라벨 7개.
func weekdayLabels(sundayFirst: Bool) -> [String] {
    let mondayFirst = ["월", "화", "수", "목", "금", "토", "일"]
    guard sundayFirst else { return mondayFirst }
    return [mondayFirst.last!] + mondayFirst.dropLast()
}

/// [sundayFirst] 기준 그리드에서 일요일이 위치한 컬럼(0-based).
func sundayColumnIndex(sundayFirst: Bool) -> Int {
    sundayFirst ? 0 : 6
}

// MARK: - Medium Widget View (좌: 오늘 경기 | 우: 미니 캘린더)

struct MediumWidgetView: View {
    let entry: ScheduleEntry

    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    private var cal: CalendarData { entry.calendar }
    private var today: TodayData { entry.today }

    private let weekdayNames = ["월", "화", "수", "목", "금", "토", "일"]
    private let weekdayShort = ["", "월", "화", "수", "목", "금", "토", "일"]

    private var bgColor: Color { isDark ? Color.black : Color.white }
    private var textColor: Color { isDark ? Color.white : Color(hex: 0x101113) }
    private var sundayColor: Color { isDark ? Color(hex: 0x9672AC) : Color(hex: 0x6D2E92) }

    private var displayYear: Int { cal.month.isEmpty ? Calendar.current.component(.year, from: Date()) : cal.year }
    private var displayMonth: Int { cal.month.isEmpty ? Calendar.current.component(.month, from: Date()) : cal.monthNum }

    private var todayDay: Int { Calendar.current.component(.day, from: Date()) }
    private var todayWeekdayLabel: String {
        let wd = today.weekday  // 1=Mon ... 7=Sun
        if wd >= 1 && wd <= 7 { return weekdayShort[wd] }
        let sysWd = Calendar.current.component(.weekday, from: Date()) // Sun=1
        let idx = (sysWd + 5) % 7 // Mon=0
        return weekdayNames[idx]
    }

    // 오늘 날짜 헤더 "07.26(일)"
    private var todayLabel: String {
        let now = Date()
        let m = Calendar.current.component(.month, from: now)
        let d = Calendar.current.component(.day, from: now)
        return String(format: "%02d.%02d(%@)", m, d, todayWeekdayLabel)
    }

    // 바로 다음 예정 경기 인덱스 찾기
    private var nextScheduledIndex: Int? {
        today.matches.firstIndex { !$0.isFinished && !$0.isLive }
    }

    var body: some View {
        HStack(spacing: 9) {
            // 왼쪽: 오늘 경기 리스트
            todayMatchesView
            // 오른쪽: 미니 캘린더
            miniCalendarView
        }
        .padding(12)
        .background(bgColor)
        .containerBackground(bgColor, for: .widget)
    }

    // MARK: - 왼쪽: 오늘 경기

    private var todayMatchesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 날짜 헤더 "07.26(일)"
            Text(todayLabel)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(textColor)
                .frame(height: 22)

            // 경기 리스트 + 세로 바
            HStack(alignment: .top, spacing: 4) {
                // 세로 그라데이션 바 (시안: width 6, height 96)
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: 93)

                // 경기 항목들
                VStack(alignment: .leading, spacing: 3) {
                    let maxShow = 3
                    let filteredMatches = filterMatchesForWidget(today.matches)
                    let nextIdx = filteredMatches.firstIndex { !$0.isFinished && !$0.isLive }

                    ForEach(0..<min(filteredMatches.count, maxShow), id: \.self) { i in
                        mediumMatchRow(filteredMatches[i], isNext: i == nextIdx)
                    }
                    if filteredMatches.count > maxShow {
                        Text("+\(filteredMatches.count - maxShow)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textColor)
                            .frame(width: 38, height: 20, alignment: .leading)
                    }
                    if filteredMatches.isEmpty {
                        Text("경기 없음")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: 0xA6A7AB))
                            .frame(height: 20)
                    }
                }
                .padding(.leading, 1)
                .padding(.vertical, 2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 지난 경기는 마지막 1개만 남기고 필터링
    private func filterMatchesForWidget(_ matches: [TodayMatch]) -> [TodayMatch] {
        let finishedMatches = matches.filter { $0.isFinished }
        let otherMatches = matches.filter { !$0.isFinished }
        let lastFinished = finishedMatches.last.map { [$0] } ?? []
        return lastFinished + otherMatches
    }

    /// AttributedString으로 취소선 적용
    private func strikethroughText(_ str: String) -> AttributedString {
        var attr = AttributedString(str)
        attr.strikethroughStyle = .single
        attr.foregroundColor = UIColor(textColor)
        return attr
    }

    /// 중간 위젯 경기 행
    /// - 지난 경기: opacity 0.6 + line-through
    /// - 라이브/바로 다음 예정: narBg 그라데이션 텍스트
    /// - 그 외 예정: 일반 텍스트 (검정/흰)
    private func mediumMatchRow(_ match: TodayMatch, isNext: Bool) -> some View {
        Group {
            if match.isFinished {
                // 지난 경기: 취소선 + 흐림
                HStack(spacing: 14) {
                    Text(strikethroughText(match.time))
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 38, alignment: .leading)
                    Text(strikethroughText(match.display))
                        .font(.system(size: 14, weight: .medium))
                }
                .opacity(0.6)
            } else if match.isLive || isNext {
                // 현재 경기 / 바로 다음 예정: 그라데이션 텍스트
                HStack(spacing: 14) {
                    Text(match.time)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 38, alignment: .leading)
                    Text(match.display)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.clear)
                .overlay(
                    LinearGradient(
                        colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .mask(
                        HStack(spacing: 14) {
                            Text(match.time)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 38, alignment: .leading)
                            Text(match.display)
                                .font(.system(size: 14, weight: .medium))
                        }
                    )
                )
            } else {
                // 그 외 예정 경기: 일반 색
                HStack(spacing: 14) {
                    Text(match.time)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 38, alignment: .leading)
                    Text(match.display)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(textColor)
            }
        }
        .frame(height: 20)
    }

    // MARK: - 오른쪽: 미니 캘린더

    private var firstWeekday: Int {
        firstWeekdayIndex(year: displayYear, month: displayMonth, sundayFirst: entry.sundayFirst)
    }

    private var daysInMonth: Int {
        var comps = DateComponents()
        comps.year = displayYear
        comps.month = displayMonth + 1
        comps.day = 0
        return Calendar.current.date(from: comps).map { Calendar.current.component(.day, from: $0) } ?? 30
    }

    private var weekCount: Int {
        ((firstWeekday + daysInMonth - 1) / 7) + 1
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        return Calendar.current.component(.year, from: now) == displayYear &&
               Calendar.current.component(.month, from: now) == displayMonth
    }

    private var miniCalendarView: some View {
        VStack(spacing: 0) {
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdayLabels(sundayFirst: entry.sundayFirst)[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(i == sundayColumnIndex(sundayFirst: entry.sundayFirst) ? sundayColor : textColor)
                        .frame(width: 20, height: 22)
                }
            }

            // 날짜 그리드
            ForEach(0..<weekCount, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dow in
                        let offset = week * 7 + dow - firstWeekday
                        let day = offset + 1
                        let isCurrent = day >= 1 && day <= daysInMonth
                        let isToday = isCurrent && isCurrentMonth && day == todayDay
                        let hasMatches = isCurrent && (cal.days[day]?.isEmpty == false)

                        VStack(spacing: 1) {
                            if isCurrent {
                                Text("\(day)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(
                                        isToday ? Color(hex: 0xFF6B6B) :
                                        dow == sundayColumnIndex(sundayFirst: entry.sundayFirst) ? sundayColor :
                                        hasMatches ? textColor :
                                        Color(hex: 0xA6A7AB)
                                    )
                                    .frame(width: 20, height: 16)
                                    .background(
                                        Group {
                                            if isToday {
                                                RoundedRectangle(cornerRadius: 7)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                Color(hex: 0xE87558).opacity(0.2),
                                                                Color(hex: 0xC865C9).opacity(0.2),
                                                                Color(hex: 0x791BB8).opacity(0.2)
                                                            ],
                                                            startPoint: .leading, endPoint: .trailing
                                                        )
                                                    )
                                            }
                                        }
                                    )
                                // 경기 있는 날만 그라데이션 dot
                                if hasMatches {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 4, height: 4)
                                } else {
                                    Spacer().frame(width: 4, height: 4)
                                }
                            } else {
                                Color.clear.frame(width: 20, height: 22)
                            }
                        }
                        .frame(width: 20, height: 22)
                    }
                }
            }
        }
        .frame(width: 140)
    }
}

// MARK: - Small Widget View (중간 위젯에서 캘린더 빠진 형태)

struct SmallWidgetView: View {
    let entry: ScheduleEntry

    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var today: TodayData { entry.today }

    private let weekdayShort = ["", "월", "화", "수", "목", "금", "토", "일"]
    private let weekdayNames = ["월", "화", "수", "목", "금", "토", "일"]

    private var bgColor: Color { isDark ? Color.black : Color.white }
    private var textColor: Color { isDark ? Color.white : Color(hex: 0x101113) }

    private var todayWeekdayLabel: String {
        let wd = today.weekday
        if wd >= 1 && wd <= 7 { return weekdayShort[wd] }
        let sysWd = Calendar.current.component(.weekday, from: Date())
        let idx = (sysWd + 5) % 7
        return weekdayNames[idx]
    }

    private var todayLabel: String {
        let now = Date()
        let m = Calendar.current.component(.month, from: now)
        let d = Calendar.current.component(.day, from: now)
        return String(format: "%02d.%02d(%@)", m, d, todayWeekdayLabel)
    }

    private var nextScheduledIndex: Int? {
        today.matches.firstIndex { !$0.isFinished && !$0.isLive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 날짜 헤더
            Text(todayLabel)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(textColor)
                .frame(height: 22)

            // 세로 바 + 경기 리스트
            HStack(alignment: .top, spacing: 4) {
                // 세로 그라데이션 바 (width 6, 경기 항목 높이에 맞춤)
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 6)

                // 경기 항목
                VStack(alignment: .leading, spacing: 3) {
                    let maxShow = 3
                    let filteredMatches = filterMatchesForWidget(today.matches)
                    let nextIdx = filteredMatches.firstIndex { !$0.isFinished && !$0.isLive }

                    ForEach(0..<min(filteredMatches.count, maxShow), id: \.self) { i in
                        smallMatchRow(filteredMatches[i], isNext: i == nextIdx)
                    }
                    if filteredMatches.count > maxShow {
                        Text("+\(filteredMatches.count - maxShow)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textColor)
                            .frame(width: 38, height: 20, alignment: .leading)
                    }
                    if filteredMatches.isEmpty {
                        Text("경기 없음")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: 0xA6A7AB))
                            .frame(height: 20)
                    }
                }
                .padding(.leading, 1)
                .padding(.vertical, 2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(bgColor)
        .containerBackground(bgColor, for: .widget)
    }

    /// 지난 경기는 마지막 1개만 남기고 필터링
    private func filterMatchesForWidget(_ matches: [TodayMatch]) -> [TodayMatch] {
        let finishedMatches = matches.filter { $0.isFinished }
        let otherMatches = matches.filter { !$0.isFinished }
        let lastFinished = finishedMatches.last.map { [$0] } ?? []
        return lastFinished + otherMatches
    }

    /// AttributedString으로 취소선 적용
    private func strikethroughText(_ str: String) -> AttributedString {
        var attr = AttributedString(str)
        attr.strikethroughStyle = .single
        attr.foregroundColor = UIColor(textColor)
        return attr
    }

    private func smallMatchRow(_ match: TodayMatch, isNext: Bool) -> some View {
        Group {
            if match.isFinished {
                HStack(spacing: 8) {
                    Text(strikethroughText(match.time))
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 38, alignment: .leading)
                    Text(strikethroughText(match.display))
                        .font(.system(size: 14, weight: .medium))
                }
                .opacity(0.6)
            } else if match.isLive || isNext {
                HStack(spacing: 8) {
                    Text(match.time)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 38, alignment: .leading)
                    Text(match.display)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.clear)
                .overlay(
                    LinearGradient(
                        colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .mask(
                        HStack(spacing: 8) {
                            Text(match.time)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 38, alignment: .leading)
                            Text(match.display)
                                .font(.system(size: 14, weight: .medium))
                        }
                    )
                )
            } else {
                HStack(spacing: 8) {
                    Text(match.time)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 38, alignment: .leading)
                    Text(match.display)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(textColor)
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Large Widget View (기존 전체 캘린더)

struct LargeWidgetView: View {
    let entry: ScheduleEntry

    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    private var cal: CalendarData { entry.calendar }
    private var weekdays: [String] { weekdayLabels(sundayFirst: entry.sundayFirst) }

    private var bgColor: Color { isDark ? Color.black : Color.white }
    private var textColor: Color { isDark ? Color.white : Color(hex: 0x101113) }
    private var sundayColor: Color { isDark ? Color(hex: 0x9672AC) : Color(hex: 0x6D2E92) }
    private var subtextColor: Color { Color(hex: 0xA6A7AB) }
    private var chipBg: Color { isDark ? Color(hex: 0x1F2024) : Color(hex: 0xFCFDFE) }
    private var chipText: Color { isDark ? Color.white : Color(hex: 0x101113) }
    private var borderColor: Color { Color(hex: 0xA6A7AB).opacity(0.5) }

    private var displayYear: Int { cal.month.isEmpty ? Calendar.current.component(.year, from: Date()) : cal.year }
    private var displayMonth: Int { cal.month.isEmpty ? Calendar.current.component(.month, from: Date()) : cal.monthNum }

    private var firstWeekday: Int {
        firstWeekdayIndex(year: displayYear, month: displayMonth, sundayFirst: entry.sundayFirst)
    }

    private var daysInMonth: Int {
        var comps = DateComponents()
        comps.year = displayYear
        comps.month = displayMonth + 1
        comps.day = 0
        return Calendar.current.date(from: comps).map { Calendar.current.component(.day, from: $0) } ?? 30
    }

    private var prevMonthDays: Int {
        var comps = DateComponents()
        comps.year = displayYear
        comps.month = displayMonth
        comps.day = 0
        return Calendar.current.date(from: comps).map { Calendar.current.component(.day, from: $0) } ?? 30
    }

    private var todayDay: Int? {
        let now = Date()
        let y = Calendar.current.component(.year, from: now)
        let m = Calendar.current.component(.month, from: now)
        if y == displayYear && m == displayMonth { return Calendar.current.component(.day, from: now) }
        return nil
    }

    private var weekCount: Int { ((firstWeekday + daysInMonth - 1) / 7) + 1 }

    var body: some View {
        VStack(spacing: 2) {
            largeHeader
            largeWeekdayRow
            largeGrid
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(bgColor)
        .containerBackground(bgColor, for: .widget)
    }

    // URL에 현재 표시 월을 포함 (prev/next 시 기준 월)
    private var prevUrl: URL {
        URL(string: "warding://widget/prev?year=\(displayYear)&month=\(displayMonth)")!
    }
    private var nextUrl: URL {
        URL(string: "warding://widget/next?year=\(displayYear)&month=\(displayMonth)")!
    }

    private var largeHeader: some View {
        HStack {
            // 좌: < 월 >
            HStack(spacing: 8) {
                Link(destination: prevUrl) {
                    Image("chevron-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(textColor)
                }
                Text(String(format: "%02d.%02d", displayYear % 100, displayMonth))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textColor)
                Link(destination: nextUrl) {
                    Image("chevron-right")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(textColor)
                }
            }
            Spacer()
            // 우: 필터 + 팀 아이콘
            HStack(spacing: 8) {
                // 필터 아이콘: 적용 시 그라데이션 보더
                Link(destination: URL(string: "warding://widget/filter")!) {
                    ZStack {
                        if entry.hasFilter {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                            Circle()
                                .fill(isDark ? Color(hex: 0x1F2024) : Color(hex: 0xFCFDFE))
                                .frame(width: 32, height: 32)
                        } else {
                            Circle()
                                .fill(isDark ? Color(hex: 0x1F2024) : Color(hex: 0xFCFDFE))
                                .frame(width: 36, height: 36)
                        }
                        Image("filter")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(textColor)
                    }
                }
                // 팀 로고: 선택 시 그라데이션 보더, 미선택 시 보더 없음
                ZStack {
                    if entry.teamSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        Circle()
                            .fill(isDark ? Color(hex: 0x1F2024) : Color.black)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(isDark ? Color(hex: 0x1F2024) : Color.black)
                            .frame(width: 36, height: 36)
                    }
                    if let uiImage = entry.teamImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 25, height: 25)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(subtextColor)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 36)
    }

    private var largeWeekdayRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdays[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(i == sundayColumnIndex(sundayFirst: entry.sundayFirst) ? sundayColor : textColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 19)
                }
            }
            // 요일 아래 그라데이션 구분선
            LinearGradient(
                colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 1)
        }
    }

    // 6주일 때 칩 최대 수 줄임
    private var maxChipsPerDay: Int { weekCount >= 6 ? 1 : 2 }

    private var largeGrid: some View {
        GeometryReader { geo in
            let totalSeparators = CGFloat(weekCount - 1)
            let rowHeight = (geo.size.height - totalSeparators) / CGFloat(weekCount)
            VStack(spacing: 0) {
                ForEach(0..<weekCount, id: \.self) { week in
                    largeWeekRow(week: week)
                        .frame(height: rowHeight)
                    if week < weekCount - 1 {
                        Rectangle().fill(Color(hex: 0xA6A7AB)).frame(height: 1)
                    }
                }
            }
        }
    }

    private func largeWeekRow(week: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { dow in
                largeDayCell(week: week, dow: dow)
            }
        }
    }

    private func largeDayCell(week: Int, dow: Int) -> some View {
        let offset = week * 7 + dow - firstWeekday
        let day = offset + 1
        let isCurrent = day >= 1 && day <= daysInMonth
        let displayDay = day < 1 ? prevMonthDays + day : (day > daysInMonth ? day - daysInMonth : day)
        let isToday = isCurrent && todayDay == day
        let matches: [MatchBrief] = isCurrent ? (cal.days[day] ?? []) : []

        return VStack(spacing: 1) {
            Text("\(displayDay)")
                .font(.system(size: weekCount >= 6 ? 9 : 10, weight: .bold))
                .foregroundColor(
                    isToday ? Color(hex: 0xFF6B6B) :
                    dow == sundayColumnIndex(sundayFirst: entry.sundayFirst) ? sundayColor : textColor
                )
                .frame(maxWidth: .infinity, alignment: .center)

            largeMatchChips(matches: matches)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 1)
        .frame(maxWidth: .infinity)
        .background(isToday ? AnyView(todayGradient) : AnyView(Color.clear))
        .opacity(isCurrent ? 1.0 : 0.5)
        .overlay(dow < 6 ? AnyView(rightBorder) : AnyView(EmptyView()))
    }

    private func largeMatchChips(matches: [MatchBrief]) -> some View {
        Group {
            if !matches.isEmpty {
                VStack(spacing: 1) {
                    ForEach(0..<min(matches.count, maxChipsPerDay), id: \.self) { i in
                        matchChipView(matches[i])
                    }
                    if matches.count > maxChipsPerDay {
                        Text("+\(matches.count - maxChipsPerDay)")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(chipText)
                    }
                }
            }
        }
    }

    private func matchChipView(_ match: MatchBrief) -> some View {
        HStack(spacing: 0) {
            Text(match.blue)
                .font(.system(size: 8))
                .foregroundColor(chipText)
            Text("VS")
                .font(.system(size: 8))
                .foregroundColor(Color(hex: 0xF03E3E))
            Text(match.red)
                .font(.system(size: 8))
                .foregroundColor(chipText)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .frame(height: 13)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(chipBg)
        )
    }

    private var todayGradient: some View {
        LinearGradient(
            colors: [Color(hex: 0xE87558).opacity(0.2), Color(hex: 0xC865C9).opacity(0.2), Color(hex: 0x791BB8).opacity(0.2)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private var rightBorder: some View {
        HStack { Spacer(); Rectangle().fill(Color(hex: 0xA6A7AB)).frame(width: 0.5) }
    }
}

// MARK: - Lock Screen Widget (잠금화면 — accessoryRectangular)

struct LockScreenWidgetView: View {
    let entry: ScheduleEntry

    private var today: TodayData { entry.today }
    private var teamCode: String { entry.teamCode }

    // 응원팀 경기만 필터
    private var teamMatches: [TodayMatch] {
        let code = teamCode
        if code.isEmpty { return today.matches }
        return today.matches.filter { $0.blueCode == code || $0.redCode == code }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 헤더: "오늘 T1 경기일정"
            HStack(spacing: 2) {
                Text("오늘")
                    .font(.system(.headline, design: .default, weight: .bold))
                if !teamCode.isEmpty {
                    Text(teamCode)
                        .font(.system(.headline, design: .default, weight: .bold))
                }
                Text("경기일정")
                    .font(.system(.headline, design: .default, weight: .bold))
            }

            if teamMatches.isEmpty {
                Text("오늘 경기 없음")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .opacity(0.8)
            } else {
                // 세로 바 + 경기 리스트
                HStack(alignment: .center, spacing: 0) {
                    // 세로 바
                    RoundedRectangle(cornerRadius: 1.5)
                        .frame(width: 3)

                    // 경기 항목
                    VStack(alignment: .leading, spacing: 1) {
                        let maxShow = 2
                        ForEach(0..<min(teamMatches.count, maxShow), id: \.self) { i in
                            HStack(spacing: 0) {
                                lockScreenMatchRow(teamMatches[i])
                                // +N: 마지막 경기 행 옆에 표시
                                if i == min(teamMatches.count, maxShow) - 1 && teamMatches.count > maxShow {
                                    Text("  +\(teamMatches.count - maxShow)")
                                        .font(.system(.caption, design: .default, weight: .medium))
                                }
                            }
                        }
                    }
                    .padding(.leading, 6)
                }
            }
        }
        .widgetURL(URL(string: "warding://widget/schedule"))
    }

    private func lockScreenMatchRow(_ match: TodayMatch) -> some View {
        HStack(spacing: 6) {
            // 대진
            HStack(spacing: 1) {
                Text(match.blueCode)
                    .fontWeight(.semibold)
                Text("VS")
                    .fontWeight(.semibold)
                Text(match.redCode)
                    .fontWeight(.semibold)
            }

            // 시간
            if !match.time.isEmpty {
                Text(match.time)
                    .fontWeight(.medium)
                    .opacity(0.8)
            }
        }
        .font(.system(.caption, design: .default))
    }
}

// MARK: - Lock Screen Circular Widget (잠금화면 아이콘 — accessoryCircular)

struct LockScreenIconView: View {
    var body: some View {
        Image("warding-icon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundColor(.white)
            .widgetURL(URL(string: "warding://widget/home"))
    }
}

// MARK: - Widget Configuration

struct WardingScheduleWidget: Widget {
    let kind: String = "WardingScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            if #available(iOSApplicationExtension 16.0, *) {
                WidgetRouter(entry: entry)
            }
        }
        .configurationDisplayName("경기 일정")
        .description("이번 달 e스포츠 경기 일정을 한눈에 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

struct WidgetRouter: View {
    let entry: ScheduleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryRectangular:
            LockScreenWidgetView(entry: entry)
        case .accessoryCircular:
            LockScreenIconView()
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct WardingWidgetBundle: WidgetBundle {
    var body: some Widget {
        WardingScheduleWidget()
        // 실시간 경기 Live Activity (iOS 16.1+).
        if #available(iOS 16.1, *) {
            MatchLiveActivityWidget()
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
