import WidgetKit
import SwiftUI

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

    var isFinished: Bool { status == "FINISHED" || status == "COMPLETED" }
    var isLive: Bool { status == "LIVE" || status == "IN_PROGRESS" }
}

// MARK: - Timeline Provider

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), calendar: .empty, today: .empty, teamImageUrl: nil, hasFilter: false, teamSelected: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let (cal, today, teamUrl, hasFilter, teamSelected) = loadData()
        completion(ScheduleEntry(date: Date(), calendar: cal, today: today, teamImageUrl: teamUrl, hasFilter: hasFilter, teamSelected: teamSelected))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let (cal, today, teamUrl, hasFilter, teamSelected) = loadData()
        let entry = ScheduleEntry(date: Date(), calendar: cal, today: today, teamImageUrl: teamUrl, hasFilter: hasFilter, teamSelected: teamSelected)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadData() -> (CalendarData, TodayData, String?, Bool, Bool) {
        guard let ud = UserDefaults(suiteName: "group.com.warding.app") else {
            return (.empty, .empty, nil, false, false)
        }
        let teamUrl = ud.string(forKey: "team_image_url")
        let hasFilter = ud.bool(forKey: "has_filter")
        let teamSelected = ud.bool(forKey: "team_selected")
        return (loadCalendar(ud), loadToday(ud), teamUrl, hasFilter, teamSelected)
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
    let hasFilter: Bool
    let teamSelected: Bool
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
    private var sundayColor: Color { isDark ? Color(hex: 0x9672AC) : Color(hex: 0x9672AC) }

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
        HStack(spacing: 8) {
            // 왼쪽: 오늘 경기 리스트
            todayMatchesView
            // 오른쪽: 미니 캘린더
            miniCalendarView
        }
        .padding(.horizontal, 12)
        .background(bgColor)
        .containerBackground(bgColor, for: .widget)
    }

    // MARK: - 왼쪽: 오늘 경기

    private var todayMatchesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 날짜 헤더
            Text(todayLabel)
                .font(.custom("Pretendard", size: 16).weight(.bold))
                .foregroundColor(textColor)

            // 경기 리스트
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    // 세로 구분선
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 2)

                    // 경기 항목들
                    VStack(alignment: .leading, spacing: 3) {
                        let maxShow = 3
                        let matches = today.matches
                        let nextIdx = nextScheduledIndex

                        ForEach(0..<min(matches.count, maxShow), id: \.self) { i in
                            matchRow(matches[i], isNext: i == nextIdx)
                        }
                        if matches.count > maxShow {
                            Text("+\(matches.count - maxShow)")
                                .font(.custom("Pretendard", size: 14).weight(.medium))
                                .foregroundColor(textColor)
                        }
                        if matches.isEmpty {
                            Text("경기 없음")
                                .font(.custom("Pretendard", size: 14).weight(.medium))
                                .foregroundColor(Color(hex: 0xA6A7AB))
                        }
                    }
                    .padding(.leading, 1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func matchRow(_ match: TodayMatch, isNext: Bool) -> some View {
        HStack(spacing: 14) {
            Text(match.time)
                .font(.custom("Pretendard", size: 14).weight(.medium))
            Text(match.display)
                .font(.custom("Pretendard", size: 14).weight(.medium))
        }
        .foregroundColor(textColor)
        .strikethrough(match.isFinished, color: textColor)
        .opacity(match.isFinished ? 0.6 : 1.0)
        .overlay(
            Group {
                if isNext {
                    // 그라데이션 텍스트 효과 — overlay + mask
                    HStack(spacing: 14) {
                        Text(match.time)
                            .font(.custom("Pretendard", size: 14).weight(.medium))
                        Text(match.display)
                            .font(.custom("Pretendard", size: 14).weight(.medium))
                    }
                    .foregroundColor(.clear)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .mask(
                        HStack(spacing: 14) {
                            Text(match.time)
                                .font(.custom("Pretendard", size: 14).weight(.medium))
                            Text(match.display)
                                .font(.custom("Pretendard", size: 14).weight(.medium))
                        }
                    )
                }
            }
        )
        .frame(height: 20)
    }

    // MARK: - 오른쪽: 미니 캘린더

    private var firstWeekday: Int {
        var comps = DateComponents()
        comps.year = displayYear
        comps.month = displayMonth
        comps.day = 1
        let date = Calendar.current.date(from: comps) ?? Date()
        let wd = Calendar.current.component(.weekday, from: date)
        return (wd + 5) % 7
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
                    Text(weekdayNames[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(i == 6 ? sundayColor : textColor)
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
                        let displayDay = isCurrent ? day : (day < 1 ? 0 : day - daysInMonth)
                        let isToday = isCurrent && isCurrentMonth && day == todayDay

                        if isCurrent || (week == 0 && day < 1) || (day > daysInMonth) {
                            Text(isCurrent ? "\(day)" : (day < 1 ? "" : "\(displayDay)"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(
                                    isToday ? Color(hex: 0xFF6B6B) :
                                    dow == 6 ? sundayColor :
                                    textColor
                                )
                                .frame(width: 20, height: 22)
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
                                .opacity(isCurrent ? 1.0 : 0.0)
                        } else {
                            Color.clear.frame(width: 20, height: 22)
                        }
                    }
                }
            }
        }
        .frame(width: 140)
    }
}

// MARK: - Small Widget View (오늘 경기 리스트만)

struct SmallWidgetView: View {
    let entry: ScheduleEntry

    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var today: TodayData { entry.today }

    private let weekdayShort = ["", "월", "화", "수", "목", "금", "토", "일"]
    private let weekdayNames = ["월", "화", "수", "목", "금", "토", "일"]

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

    private var bgColor: Color { isDark ? Color.black : Color.white }
    private var textColor: Color { isDark ? Color.white : Color(hex: 0x101113) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(todayLabel)
                .font(.custom("Pretendard", size: 16).weight(.bold))
                .foregroundColor(textColor)

            // 세로선 + 경기 리스트
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 2)

                VStack(alignment: .leading, spacing: 3) {
                    let maxShow = 3
                    let matches = today.matches
                    let nextIdx = nextScheduledIndex

                    ForEach(0..<min(matches.count, maxShow), id: \.self) { i in
                        smallMatchRow(matches[i], isNext: i == nextIdx)
                    }
                    if matches.count > maxShow {
                        Text("+\(matches.count - maxShow)")
                            .font(.custom("Pretendard", size: 14).weight(.medium))
                            .foregroundColor(textColor)
                    }
                    if matches.isEmpty {
                        Text("경기 없음")
                            .font(.custom("Pretendard", size: 14).weight(.medium))
                            .foregroundColor(Color(hex: 0xA6A7AB))
                    }
                }
                .padding(.leading, 1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(bgColor)
        .containerBackground(bgColor, for: .widget)
    }

    private func smallMatchRow(_ match: TodayMatch, isNext: Bool) -> some View {
        HStack(spacing: 8) {
            Text(match.time)
                .font(.custom("Pretendard", size: 14).weight(.medium))
            Text(match.display)
                .font(.custom("Pretendard", size: 14).weight(.medium))
        }
        .foregroundColor(textColor)
        .strikethrough(match.isFinished, color: textColor)
        .opacity(match.isFinished ? 0.6 : 1.0)
        .overlay(
            Group {
                if isNext {
                    HStack(spacing: 8) {
                        Text(match.time)
                            .font(.custom("Pretendard", size: 14).weight(.medium))
                        Text(match.display)
                            .font(.custom("Pretendard", size: 14).weight(.medium))
                    }
                    .foregroundColor(.clear)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xE87558), Color(hex: 0xC865C9), Color(hex: 0x791BB8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .mask(
                        HStack(spacing: 8) {
                            Text(match.time)
                                .font(.custom("Pretendard", size: 14).weight(.medium))
                            Text(match.display)
                                .font(.custom("Pretendard", size: 14).weight(.medium))
                        }
                    )
                }
            }
        )
        .frame(height: 20)
    }
}

// MARK: - Large Widget View (기존 전체 캘린더)

struct LargeWidgetView: View {
    let entry: ScheduleEntry

    @Environment(\.colorScheme) var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    private var cal: CalendarData { entry.calendar }
    private let weekdays = ["월", "화", "수", "목", "금", "토", "일"]

    private var bgColor: Color { isDark ? Color.black : Color.white }
    private var textColor: Color { isDark ? Color.white : Color(hex: 0x101113) }
    private var sundayColor: Color { isDark ? Color(hex: 0xFFBCBC) : Color(hex: 0xFFBCBC) }
    private var subtextColor: Color { Color(hex: 0xA6A7AB) }
    private var chipBg: Color { isDark ? Color(hex: 0x1F2024) : Color(hex: 0xFCFDFE) }
    private var chipText: Color { isDark ? Color.white : Color(hex: 0x101113) }
    private var borderColor: Color { Color(hex: 0xA6A7AB).opacity(0.5) }

    private var displayYear: Int { cal.month.isEmpty ? Calendar.current.component(.year, from: Date()) : cal.year }
    private var displayMonth: Int { cal.month.isEmpty ? Calendar.current.component(.month, from: Date()) : cal.monthNum }

    private var firstWeekday: Int {
        var comps = DateComponents()
        comps.year = displayYear
        comps.month = displayMonth
        comps.day = 1
        let date = Calendar.current.date(from: comps) ?? Date()
        let wd = Calendar.current.component(.weekday, from: date)
        return (wd + 5) % 7
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

    private var largeHeader: some View {
        HStack {
            // 좌: < 월 >
            HStack(spacing: 8) {
                Link(destination: URL(string: "warding://widget/prev")!) {
                    Image("chevron-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(textColor)
                }
                Text(String(format: "%02d.%02d", displayYear % 100, displayMonth))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textColor)
                Link(destination: URL(string: "warding://widget/next")!) {
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
                // 필터 아이콘: 필터 적용 시 #FCFDFE 배경 + #101113 아이콘
                Link(destination: URL(string: "warding://widget/filter")!) {
                    Circle()
                        .fill(entry.hasFilter
                            ? Color(hex: 0xFCFDFE)
                            : (isDark ? Color(hex: 0x1F2024) : Color(hex: 0xFCFDFE)))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image("filter")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(entry.hasFilter
                                    ? Color(hex: 0x101113)
                                    : textColor)
                        )
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
                    if let urlStr = entry.teamImageUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 16))
                                .foregroundColor(subtextColor)
                        }
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
                        .foregroundColor(i == 6 ? sundayColor : textColor)
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

    private var largeGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<weekCount, id: \.self) { week in
                largeWeekRow(week: week)
                if week < weekCount - 1 {
                    Rectangle().fill(Color(hex: 0xA6A7AB)).frame(height: 1)
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

        return VStack(spacing: 2) {
            Text("\(displayDay)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(
                    isToday ? Color(hex: 0xFF6B6B) :
                    dow == 6 ? sundayColor : textColor
                )
                .frame(maxWidth: .infinity, alignment: .center)

            largeMatchChips(matches: matches)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
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
                    ForEach(0..<min(matches.count, 2), id: \.self) { i in
                        matchChipView(matches[i])
                    }
                    if matches.count > 2 {
                        Text("+\(matches.count - 2)")
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
