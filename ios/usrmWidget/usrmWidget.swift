//
//  usrmWidget.swift
//  usrmWidget
//
//  Minimalist iOS Widget: Matches App UI strictly.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data Model
struct DayData {
    let count: Int
    let layoutIndex: Int
    let targetCount: Int
    let intensities: [Int] // 0 or 1, count = 4
    let isToday: Bool
}

struct WidgetData {
    let dashboardName: String
    let streakDays: Int
    let todayCount: Int
    let weekData: [DayData]
    let weekMaxLevel: Int
    let monthData: [DayData]
    let monthStartWeekday: Int
    let monthDays: Int
    let monthYear: String
    let todayWeekdayIndex: Int
    let todayDayOfMonth: Int
}

// MARK: - Timeline Provider
struct Provider: AppIntentTimelineProvider {
    let appGroupId = "group.com.antigravity.usrm"
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), data: sampleData(), showDigitalTime: false)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, data: loadData(for: configuration), showDigitalTime: false)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        let data = loadData(for: configuration)
        let showTime = UserDefaults(suiteName: appGroupId)?.bool(forKey: "showDigitalTime") ?? false
        
        for secondOffset in 0..<60 {
            if let entryDate = Calendar.current.date(byAdding: .second, value: secondOffset, to: currentDate) {
                let entry = SimpleEntry(date: entryDate, configuration: configuration, data: data, showDigitalTime: showTime)
                entries.append(entry)
            }
        }
        
        return Timeline(entries: entries, policy: .atEnd)
    }
    
    private func loadData(for config: ConfigurationAppIntent) -> WidgetData {
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            return sampleData()
        }
        
        let dash = config.dashboardName
        let streak = userDefaults.integer(forKey: "streak_\(dash)")
        let todayCount = userDefaults.integer(forKey: "todayCount_\(dash)")
        let weekMax = max(userDefaults.integer(forKey: "weekMaxLevel_\(dash)"), 5)
        let todayIdx = userDefaults.integer(forKey: "todayWeekdayIndex_\(dash)")
        let todayDay = userDefaults.integer(forKey: "todayDayOfMonth_\(dash)")
        
        let wCounts = parseCSV(userDefaults.string(forKey: "weekCounts_\(dash)") ?? "")
        let wLayouts = parseCSV(userDefaults.string(forKey: "weekLayouts_\(dash)") ?? "")
        let wTargets = parseCSV(userDefaults.string(forKey: "weekTargets_\(dash)") ?? "")
        let wIntsString = userDefaults.string(forKey: "weekIntensities_\(dash)") ?? ""
        let wInts = wIntsString.split(separator: ",").map(String.init)
        
        var weekData: [DayData] = []
        for i in 0..<7 {
            weekData.append(DayData(
                count: i < wCounts.count ? wCounts[i] : 0,
                layoutIndex: i < wLayouts.count ? wLayouts[i] : 0,
                targetCount: i < wTargets.count ? wTargets[i] : 1,
                intensities: i < wInts.count ? parseBinary(wInts[i]) : [0,0,0,0],
                isToday: i == todayIdx
            ))
        }
        
        let mCounts = parseCSV(userDefaults.string(forKey: "monthCounts_\(dash)") ?? "")
        let mLayouts = parseCSV(userDefaults.string(forKey: "monthLayouts_\(dash)") ?? "")
        let mTargets = parseCSV(userDefaults.string(forKey: "monthTargets_\(dash)") ?? "")
        let mIntsString = userDefaults.string(forKey: "monthIntensities_\(dash)") ?? ""
        let mInts = mIntsString.split(separator: ",").map(String.init)
        
        var monthData: [DayData] = []
        for i in 0..<mCounts.count {
            monthData.append(DayData(
                count: mCounts[i],
                layoutIndex: i < mLayouts.count ? mLayouts[i] : 0,
                targetCount: i < mTargets.count ? mTargets[i] : 1,
                intensities: i < mInts.count ? parseBinary(mInts[i]) : [0,0,0,0],
                isToday: (i + 1) == todayDay
            ))
        }
        
        return WidgetData(
            dashboardName: dash,
            streakDays: streak,
            todayCount: todayCount,
            weekData: weekData,
            weekMaxLevel: weekMax,
            monthData: monthData,
            monthStartWeekday: userDefaults.integer(forKey: "monthStartWeekday_\(dash)"),
            monthDays: userDefaults.integer(forKey: "monthDays_\(dash)"),
            monthYear: userDefaults.string(forKey: "monthYear_\(dash)") ?? "",
            todayWeekdayIndex: todayIdx,
            todayDayOfMonth: todayDay
        )
    }
    
    private func parseCSV(_ str: String) -> [Int] {
        if str.isEmpty { return [] }
        return str.split(separator: ",").map { Int($0) ?? 0 }
    }
    
    private func parseBinary(_ str: String) -> [Int] {
        return str.map { $0 == "1" ? 1 : 0 }
    }
    
    private func sampleData() -> WidgetData {
        let week = (0..<7).map { i in
            DayData(count: i == 1 ? 2 : 0, layoutIndex: 0, targetCount: 1, intensities: [1,0,0,0], isToday: i == 1)
        }
        return WidgetData(
            dashboardName: "mood", streakDays: 12, todayCount: 1,
            weekData: week, weekMaxLevel: 5,
            monthData: week, monthStartWeekday: 0, monthDays: 31, monthYear: "2026.03",
            todayWeekdayIndex: 1, todayDayOfMonth: 9
        )
    }
}

// MARK: - Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let data: WidgetData
    let showDigitalTime: Bool
}

// MARK: - Minimalist Cell View
struct GridCellView: View {
    let dayData: DayData
    let isDark: Bool
    let size: CGFloat
    let showDayNumber: Int? // Optional day number for Large widget
    
    var body: some View {
        let fg = isDark ? Color.white : Color.black
        let bgOpacity = isDark ? 0.1 : 0.05
        
        VStack(spacing: 2) {
            if let day = showDayNumber {
                Text("\(day)")
                    .font(.system(size: 7, weight: .light, design: .monospaced))
                    .foregroundStyle(fg.opacity(0.3))
            }
            
            ZStack {
                // Background Shell
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(fg.opacity(bgOpacity))
                
                // Content
                GeometryReader { geo in
                    renderContent(in: geo.size)
                }
                
                // Today Highlight
                if dayData.isToday {
                    RoundedRectangle(cornerRadius: size * 0.12)
                        .stroke(fg.opacity(0.6), lineWidth: 1.0)
                }
            }
            .frame(width: size, height: size)
        }
    }
    
    @ViewBuilder
    private func renderContent(in area: CGSize) -> some View {
        let ints = dayData.intensities
        let target = dayData.targetCount
        let fg = isDark ? Color.white : Color.black
        let radius = size * 0.1
        
        // Intensity Mode (Fallback/Logic based on targetCount == 1 and no layout index)
        if dayData.layoutIndex == 0 && target == 1 {
            let opacity = Double(dayData.count) / 5.0
            RoundedRectangle(cornerRadius: radius)
                .fill(fg.opacity(opacity))
                .blur(radius: opacity > 0 ? 1 : 0) // Subtle glow for intensity
        } else {
            // Divided Mode
            renderDividedLayout(in: area)
        }
    }
    
    @ViewBuilder
    private func renderDividedLayout(in area: CGSize) -> some View {
        let ints = dayData.intensities
        let radius = size * 0.1
        
        switch dayData.layoutIndex {
        case 1: // Vertical
            HStack(spacing: 1) {
                subCell(ints[0], radius: radius).frame(width: area.width/2 - 0.5)
                subCell(ints[1], radius: radius).frame(width: area.width/2 - 0.5)
            }
        case 2: // Horizontal
            VStack(spacing: 1) {
                subCell(ints[0], radius: radius).frame(height: area.height/2 - 0.5)
                subCell(ints[1], radius: radius).frame(height: area.height/2 - 0.5)
            }
        case 3: // Split Right
            HStack(spacing: 1) {
                subCell(ints[0], radius: radius).frame(width: area.width/2 - 0.5)
                VStack(spacing: 1) {
                    subCell(ints[1], radius: radius)
                    subCell(ints[2], radius: radius)
                }.frame(width: area.width/2 - 0.5)
            }
        case 4: // Split Left
            HStack(spacing: 1) {
                VStack(spacing: 1) {
                    subCell(ints[0], radius: radius)
                    subCell(ints[1], radius: radius)
                }.frame(width: area.width/2 - 0.5)
                subCell(ints[2], radius: radius).frame(width: area.width/2 - 0.5)
            }
        case 5: // Top Full
            VStack(spacing: 1) {
                subCell(ints[0], radius: radius).frame(height: area.height/2 - 0.5)
                HStack(spacing: 1) {
                    subCell(ints[1], radius: radius)
                    subCell(ints[2], radius: radius)
                }.frame(height: area.height/2 - 0.5)
            }
        case 6: // Bottom Full
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    subCell(ints[0], radius: radius)
                    subCell(ints[1], radius: radius)
                }.frame(height: area.height/2 - 0.5)
                subCell(ints[2], radius: radius).frame(height: area.height/2 - 0.5)
            }
        default: // Default/2x2
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    subCell(ints[0], radius: radius)
                    subCell(ints[1], radius: radius)
                }
                HStack(spacing: 1) {
                    subCell(ints[2], radius: radius)
                    subCell(ints[3], radius: radius)
                }
            }
        }
    }
    
    private func subCell(_ val: Int, radius: CGFloat) -> some View {
        let fg = isDark ? Color.white : Color.black
        return RoundedRectangle(cornerRadius: radius)
            .fill(fg.opacity(val > 0 ? 0.9 : 0.0))
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let entry: SimpleEntry
    var isDark: Bool {
        switch entry.configuration.theme {
        case .black: return true
        case .white: return false
        case .daylight:
            let hour = Calendar.current.component(.hour, from: entry.date)
            return hour >= 12
        }
    }
    var fg: Color { isDark ? .white : .black }
    
    var body: some View {
        VStack(spacing: 0) {
            TimeHeaderView(date: entry.date, color: fg, hideAMPM: entry.configuration.theme == .daylight)
                .padding(.top, 12)
            
            Spacer()
            
            GridCellView(dayData: entry.data.weekData[entry.data.todayWeekdayIndex], isDark: isDark, size: 60, showDayNumber: nil)
            
            Spacer()
            
            Text("\(entry.data.streakDays)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(fg.opacity(0.3))
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let entry: SimpleEntry
    var isDark: Bool {
        switch entry.configuration.theme {
        case .black: return true
        case .white: return false
        case .daylight:
            let hour = Calendar.current.component(.hour, from: entry.date)
            return hour >= 12
        }
    }
    var fg: Color { isDark ? .white : .black }
    
    var body: some View {
        VStack(spacing: 0) {
            TimeHeaderView(date: entry.date, color: fg, hideAMPM: entry.configuration.theme == .daylight)
                .padding(.top, 15)
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    GridCellView(dayData: entry.data.weekData[i], isDark: isDark, size: 36, showDayNumber: nil)
                }
            }
            
            Spacer()
            
            Text("\(entry.data.streakDays)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(fg.opacity(0.3))
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let entry: SimpleEntry
    var isDark: Bool {
        switch entry.configuration.theme {
        case .black: return true
        case .white: return false
        case .daylight:
            let hour = Calendar.current.component(.hour, from: entry.date)
            return hour >= 12
        }
    }
    var fg: Color { isDark ? .white : .black }
    
    var body: some View {
        VStack(spacing: 0) {
            TimeHeaderView(date: entry.date, color: fg, hideAMPM: entry.configuration.theme == .daylight)
                .padding(.top, 20)
            
            Spacer()
            
            let start = entry.data.monthStartWeekday
            let days = entry.data.monthDays
            let rows = (start + days + 6) / 7
            
            VStack(spacing: 8) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { c in
                            let idx = r * 7 + c - start
                            if idx >= 0 && idx < days {
                                GridCellView(dayData: entry.data.monthData[idx], isDark: isDark, size: 32, showDayNumber: idx + 1)
                            } else {
                                Color.clear.frame(width: 32, height: 32)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Text("\(entry.data.streakDays)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(fg.opacity(0.3))
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Hybrid Clock View
struct UsrmHybridClockView: View {
    let entry: SimpleEntry
    let isDark: Bool
    
    var body: some View {
        let date = entry.date
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        
        let hourAngle = Double(hour % 12) * 30.0 + Double(minute) * 0.5
        let minuteAngle = Double(minute) * 6.0
        // Cumulative angle: (minutes since start of hour * 60 + seconds) * 6 degrees per second
        // This ensures the angle always increases during the timeline, preventing the 59 -> 0 back-spin.
        let secondAngle = Double(minute * 60 + second) * 6.0
        
        let orbitRadius: CGFloat = 60
        let fg: Color = isDark ? .white : .black
        let bg: Color = isDark ? .black : .white
        let secondSize: CGFloat = 20 // Top Layer (grav Fit)
        let minuteSize: CGFloat = 20 // Middle Layer (grav Fit)
        let hourSize: CGFloat = 20   // Bottom Layer (grav Fit)
        
        ZStack {
            bg.ignoresSafeArea()
            
            // Interaction Layer: Invisible Button for Toggle
            Button(intent: ToggleTimeIntent()) {
                Color.clear
            }
            .buttonStyle(.plain) // No visual feedback (stealthy)
            
            // Single Orbit
            Circle()
                .stroke(fg.opacity(0.8), lineWidth: 1)
                .frame(width: orbitRadius * 2, height: orbitRadius * 2)
            
            // 1. Hour (Square) - Bottom Layer (16pt)
            HandSquare(angle: hourAngle, radius: orbitRadius, size: hourSize, color: bg, strokeColor: fg)
            
            // 2. Minute (Circle) - Mid Layer (18pt)
            HandCircle(angle: minuteAngle, radius: orbitRadius, size: minuteSize, color: fg)
            
            // 3. Second (Triangle) - Top Layer (22pt)
            HandTriangle(angle: secondAngle, radius: orbitRadius, size: secondSize, color: .gray)
                .animation(.linear(duration: 1.0), value: date) // Smooth interpolation
            
            // Interactive Digital Time Overlay (Minimalist)
            if entry.showDigitalTime {
                let hideAMPM = entry.configuration.theme == .daylight
                VStack {
                    Spacer()
                    Text(entry.date, formatter: hideAMPM ? UsrmHybridClockView.format24 : UsrmHybridClockView.formatTimeWithOptionalAMPM)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(fg)
                        .padding(.bottom, 45) // Shifted up to clear Orbit (60)
                }
            }
        }
    }
    
    static let format24: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    static let formatTimeWithOptionalAMPM: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

// MARK: - Helper Views
struct TimeHeaderView: View {
    let date: Date
    let color: Color
    let hideAMPM: Bool
    
    var body: some View {
        let f12 = DateFormatter()
        f12.dateFormat = hideAMPM ? "h:mm" : "h:mm a"
        
        let f24 = DateFormatter()
        f24.dateFormat = "HH:mm"
        
        return Text("\(f12.string(from: date)) | \(f24.string(from: date))")
            .font(.system(size: 8, weight: .light, design: .monospaced))
            .foregroundStyle(color.opacity(0.4))
    }
}

// MARK: - Hand Components
struct HandCircle: View {
    let angle: Double
    let radius: CGFloat
    let size: CGFloat
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            // [ROTATIONAL ALIGNMENT] Unified flow: rotates with the orbit
            .offset(x: radius)
            .rotationEffect(.degrees(angle - 90))
    }
}

struct HandSquare: View {
    let angle: Double
    let radius: CGFloat
    let size: CGFloat
    let color: Color
    let strokeColor: Color
    
    var body: some View {
        Rectangle()
            .fill(color)
            .overlay(Rectangle().stroke(strokeColor, lineWidth: 1))
            .frame(width: size, height: size)
            // [ROTATIONAL ALIGNMENT] Unified flow: rotates with the orbit (Tangential)
            .offset(x: radius)
            .rotationEffect(.degrees(angle - 90))
    }
}

struct HandTriangle: View {
    let angle: Double
    let radius: CGFloat
    let size: CGFloat
    let color: Color
    
    var body: some View {
        TrianglePath()
            .fill(color)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(90)) // Apex points OUT (x+)
            // [ZENITH POINTER] Centered on orbit as per Master's request
            .offset(x: radius)
            .rotationEffect(.degrees(angle - 90))
    }
}

struct TrianglePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Apex at the top-center (Upright)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct AMPMIcon: View {
    let isAM: Bool
    let color: Color
    
    var body: some View {
        Image(systemName: isAM ? "sun.max" : "moon")
            .font(.system(size: 10))
            .foregroundStyle(color.opacity(0.5))
    }
}

// MARK: - Entry View
struct UsrmWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        let theme = entry.configuration.theme
        let isDark: Bool
        switch theme {
        case .black: isDark = true
        case .white: isDark = false
        case .daylight:
            let hour = Calendar.current.component(.hour, from: entry.date)
            isDark = hour >= 12
        }
        
        return UsrmHybridClockView(entry: entry, isDark: isDark)
            .containerBackground(for: .widget) {
                isDark ? Color.black : Color.white
            }
    }
}

struct usrmWidget: Widget {
    let kind: String = "usrmWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            UsrmWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("usrm")
        .description("Minimalist record tracking.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
