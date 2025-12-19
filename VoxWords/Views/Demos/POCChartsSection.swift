import SwiftUI

#if canImport(Charts)
import Charts
#endif

/// Swift Charts POC for the screenshots:
/// - A weekly line chart (sleep quality trend style)
/// - A multi-lane segmented chart (sleep stages style)
/// - A heart-rate line chart (red) with drag-to-inspect
@available(iOS 16.0, *)
struct POCChartsSection: View {
    struct DayPoint: Identifiable, Hashable {
        let id = UUID()
        let dayIndex: Int
        let value: Double
    }

    enum SleepLane: String, CaseIterable, Identifiable {
        case awake = "清醒"
        case rem = "快速眼动"
        case core = "核心睡眠"
        case deep = "深度睡眠"
        var id: String { rawValue }
    }

    struct Stage: Identifiable, Hashable {
        let id = UUID()
        let lane: SleepLane
        let startMinute: Double
        let endMinute: Double
        let color: Color
    }

    struct HRPoint: Identifiable, Hashable {
        let id = UUID()
        let minute: Double
        let bpm: Double
    }

    private let week: [DayPoint] = [
        .init(dayIndex: 5, value: 0.15),
        .init(dayIndex: 6, value: 0.18),
        .init(dayIndex: 7, value: 0.78),
        .init(dayIndex: 8, value: 0.62),
        .init(dayIndex: 9, value: 0.12),
        .init(dayIndex: 10, value: 0.81),
        .init(dayIndex: 11, value: 0.74)
    ]

    /// Example: one-night sleep stages (minutes from start)
    private let stages: [Stage] = [
        .init(lane: .awake, startMinute: 0, endMinute: 6, color: .orange),
        .init(lane: .core, startMinute: 6, endMinute: 16, color: Color(red: 0.08, green: 0.58, blue: 0.98)),
        .init(lane: .core, startMinute: 16, endMinute: 28, color: Color(red: 0.08, green: 0.58, blue: 0.98)),
        .init(lane: .deep, startMinute: 28, endMinute: 40, color: Color(red: 0.45, green: 0.33, blue: 0.95)),
        .init(lane: .core, startMinute: 40, endMinute: 125, color: Color(red: 0.08, green: 0.58, blue: 0.98)),
        .init(lane: .deep, startMinute: 125, endMinute: 145, color: Color(red: 0.45, green: 0.33, blue: 0.95)),
        .init(lane: .rem, startMinute: 145, endMinute: 190, color: Color(red: 0.28, green: 0.85, blue: 0.90)),
        .init(lane: .awake, startMinute: 190, endMinute: 215, color: .orange),
        .init(lane: .core, startMinute: 215, endMinute: 250, color: Color(red: 0.08, green: 0.58, blue: 0.98)),
        .init(lane: .deep, startMinute: 250, endMinute: 268, color: Color(red: 0.45, green: 0.33, blue: 0.95)),
        .init(lane: .core, startMinute: 268, endMinute: 290, color: Color(red: 0.08, green: 0.58, blue: 0.98))
    ]

    private let hr: [HRPoint] = {
        // Deterministic-ish red line similar to the screenshot.
        var points: [HRPoint] = []
        var bpm = 74.0
        for m in stride(from: 0.0, through: 395.0, by: 5.0) {
            let jitter = (sin(m / 22.0) * 2.3) + (sin(m / 7.0) * 1.2)
            let drift = (m > 260 ? (m - 260) / 120.0 : 0) * 3.0
            bpm = max(59, min(87, bpm + jitter * 0.08 + drift * 0.02))
            points.append(.init(minute: m, bpm: bpm))
        }
        return points
    }()

    @State private var selectedDay: DayPoint?
    @State private var selectedHR: HRPoint?

    var body: some View {
        VStack(spacing: 14) {
            sleepQualityCard
            sleepStagesCard
            metricsGrid
            heartRateCard
        }
    }

    private var sleepQualityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("5小时 43分钟")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("低")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.red.opacity(0.95))
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("81%")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.blue.opacity(0.95))
                        Text("睡眠质量")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                }
            }

#if canImport(Charts)
            ZStack {
                Chart(week) { p in
                    AreaMark(
                        x: .value("Day", p.dayIndex),
                        y: .value("Value", p.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.35), Color.blue.opacity(0.00)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Day", p.dayIndex),
                        y: .value("Value", p.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.blue.opacity(0.92))

                    PointMark(
                        x: .value("Day", p.dayIndex),
                        y: .value("Value", p.value)
                    )
                    .symbolSize(70)
                    .foregroundStyle(Color.blue.opacity(0.95))

                    if let sel = selectedDay {
                        RuleMark(x: .value("Selected", sel.dayIndex))
                            .lineStyle(.init(lineWidth: 2))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: week.map(\.dayIndex)) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.10))
                        AxisTick().foregroundStyle(Color.white.opacity(0.12))
                        AxisValueLabel {
                            if let day = value.as(Int.self) {
                                Text("\(day)")
                                    .foregroundStyle(Color.white.opacity(0.55))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 170)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let origin = geo[proxy.plotAreaFrame].origin
                                        let xPos = value.location.x - origin.x
                                        if let day: Int = proxy.value(atX: xPos) {
                                            if let p = week.first(where: { $0.dayIndex == day }) {
                                                selectedDay = p
                                            } else {
                                                // snap to nearest
                                                let nearest = week.min(by: { abs($0.dayIndex - day) < abs($1.dayIndex - day) })
                                                selectedDay = nearest
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        // keep selection (like many health apps) instead of clearing
                                    }
                            )
                    }
                }
            }
#else
            Text("当前环境不可用 Charts")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
#endif
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var sleepStagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
#if canImport(Charts)
            Chart(stages) { s in
                BarMark(
                    xStart: .value("Start", s.startMinute),
                    xEnd: .value("End", s.endMinute),
                    y: .value("Lane", s.lane.rawValue)
                )
                .foregroundStyle(s.color)
                .opacity(0.95)
                .cornerRadius(6)
            }
            .chartYScale(domain: SleepLane.allCases.map(\.rawValue))
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            .frame(height: 110)
#else
            Text("当前环境不可用 Charts")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
#endif

            HStack {
                Text("01:09")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("恢复性睡眠：2 小时 31 分钟")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.60))
                Spacer()
                Text("07:49")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [.init(.flexible(), spacing: 12), .init(.flexible(), spacing: 12)], spacing: 12) {
            metricCard(title: "清醒状态", percent: "19%", detail: "1时20分", accent: .red)
            metricCard(title: "快速眼动", percent: "24%", detail: "1时41分", accent: .green)
            metricCard(title: "核心睡眠", percent: "45%", detail: "3时9分", accent: .green)
            metricCard(title: "深度睡眠", percent: "12%", detail: "50分", accent: .red)
        }
    }

    private func metricCard(title: String, percent: String, detail: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(percent)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                Spacer()
                Circle()
                    .fill(accent.opacity(0.95))
                    .frame(width: 10, height: 10)
            }
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
            Text(detail)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.50))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var heartRateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
#if canImport(Charts)
            Chart(hr) { p in
                AreaMark(
                    x: .value("Minute", p.minute),
                    y: .value("BPM", p.bpm)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.red.opacity(0.25), Color.red.opacity(0.00)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Minute", p.minute),
                    y: .value("BPM", p.bpm)
                )
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.red.opacity(0.92))

                if let sel = selectedHR {
                    RuleMark(x: .value("Selected", sel.minute))
                        .lineStyle(.init(lineWidth: 2))
                        .foregroundStyle(Color.white.opacity(0.20))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 90)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    let xPos = value.location.x - origin.x
                                    if let minute: Double = proxy.value(atX: xPos) {
                                        let nearest = hr.min(by: { abs($0.minute - minute) < abs($1.minute - minute) })
                                        selectedHR = nearest
                                    }
                                }
                        )
                }
            }
#else
            Text("当前环境不可用 Charts")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
#endif

            HStack {
                Text("01:11")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("睡眠心率：74 bpm (59–87)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.60))
                Spacer()
                Text("07:46")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
