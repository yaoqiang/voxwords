import SwiftUI
import SpriteKit
import SwiftData

// MARK: - Home (CapWords-like)

struct HomeView: View {
    @Binding var selectedDay: Date
    let entries: [WordEntry]
    let isActive: Bool
    let onOpenDay: (Date) -> Void
    let onOpenSettings: () -> Void

    private var todayKey: Date { Calendar.current.startOfDay(for: Date()) }

    private var groupedByMonth: [(month: Date, days: [Date])] {
        let cal = Calendar.current
        let allDays = Set(entries.map { cal.startOfDay(for: $0.createdAt) }).union([todayKey])
        let sorted = allDays.sorted(by: >)

        var buckets: [Date: [Date]] = [:]
        for d in sorted {
            let comps = cal.dateComponents([.year, .month], from: d)
            let monthKey = cal.date(from: comps) ?? d
            buckets[monthKey, default: []].append(d)
        }
        return buckets.keys.sorted(by: >).map { key in
            (month: key, days: buckets[key]!.sorted(by: >))
        }
    }

    private var totalCount: Int { entries.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                topBar
                heroArea

                ForEach(groupedByMonth, id: \.month) { section in
                    monthSection(section.month, days: section.days)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.top, 16)
            .padding(.bottom, 26)
        }
    }

    private var topBar: some View {
        HStack {
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 44, height: 44)
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 8)
                .overlay(
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.55))
                )

            Spacer()

            Text("Home")
                .font(.system(size: 36, weight: .regular, design: .serif))
                .foregroundStyle(Color.black.opacity(0.88))

            Spacer()

            Button {
                HapticManager.shared.selectionChanged()
                onOpenSettings()
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 8)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.50))
                    )
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .leading) {
            Text("VoxWords · Audio-first")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.45))
                .offset(x: 0, y: 44)
        }
        .padding(.bottom, 24)
    }

    private var heroArea: some View {
        VStack(spacing: 14) {
            WordsGravityCard(wordCount: max(1, totalCount), isActive: isActive)
                .frame(height: 240)
        }
        .padding(.bottom, 10)
    }

    private func monthSection(_ month: Date, days: [Date]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(month, format: .dateTime.month(.wide))
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(Color.black.opacity(0.88))

            ForEach(days, id: \.self) { day in
                let key = Calendar.current.startOfDay(for: day)
                let dayEntries = entries.filter { Calendar.current.startOfDay(for: $0.createdAt) == key }
                let count = dayEntries.count
                Button {
                    selectedDay = key
                    onOpenDay(key)
                } label: {
                    CapDayCard(
                        day: key,
                        count: count,
                        sampleWords: Array(dayEntries.prefix(4).map { $0.targetText })
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
    }
}

struct CapDayCard: View {
    let day: Date
    let count: Int
    let sampleWords: [String]

    private var bg: Color {
        if count == 0 { return Color.black.opacity(0.06) }
        if count < 4 { return Color(red: 0.93, green: 0.90, blue: 0.92) }
        if count < 10 { return Color(red: 0.88, green: 0.84, blue: 0.90) }
        return Color(red: 0.84, green: 0.80, blue: 0.90)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(Color.black.opacity(0.82))

            Text(count == 0 ? "Start your day with a new word." : "\(count) Words")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.45))

            HStack(spacing: 14) {
                ForEach(Array(sampleWords.prefix(4).enumerated()), id: \.offset) { _, w in
                    Text(String(w.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
                Spacer()
            }
            .frame(height: 54)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(bg)
        )
    }
}

struct WordsGravityCard: View {
    let wordCount: Int
    let isActive: Bool
    @State private var resetToken = UUID()

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.07))

            VStack(spacing: 12) {
                HStack {
                    Text("Words Gravity")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.75))
                    Spacer()
                    Text("\(wordCount) words")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.45))
                    Button {
                        HapticManager.shared.softImpact()
                        resetToken = UUID()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.55))
                            .padding(10)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                ZStack(alignment: .bottom) {
                    WordsBowlFillShape(rimRatio: 0.55, depthRatio: 0.22)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .allowsHitTesting(false)

                    if isActive {
                        GeometryReader { proxy in
                            let scene = MoodGravityScene(
                                size: proxy.size,
                                config: .init(
                                    ballCount: min(32, max(6, wordCount)),
                                    ballRadius: 13,
                                    gravity: .init(dx: 0, dy: -16),
                                    usesDeviceGravity: true,
                                    gravityStrength: 16,
                                    gravitySmoothing: 0.22,
                                    rimY: 96,
                                    bowlDepth: 56,
                                    restitution: 0.14,
                                    linearDamping: 1.55,
                                    friction: 0.70,
                                    simplifiedDropHaptics: false,
                                    collisionImpulseThreshold: 2.2,
                                    hapticMaxHz: 5,
                                    onlyBallBallHaptics: true,
                                    settleHapticEnabled: false,
                                    showsBowlStroke: false,
                                    deviceGravityDeadzone: 0.10
                                )
                            )
                            SpriteView(scene: scene, options: [.allowsTransparency])
                                .id(resetToken)
                                .background(Color.clear)
                                .allowsHitTesting(false)
                                .focusable(false)
                        }
                    } else {
                        // When Home is not visible (e.g. in Daily), stop SpriteKit/CoreMotion/haptics completely.
                        Color.clear
                            .frame(height: 170)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)
    }
}

struct WordsBowlFillShape: Shape {
    var rimRatio: CGFloat // 0...1
    var depthRatio: CGFloat // 0...1

    func path(in rect: CGRect) -> Path {
        let rimY = rect.height * rimRatio
        let dipY = min(rect.maxY - 6, rimY + rect.height * depthRatio)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rimY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rimY),
            control: CGPoint(x: rect.midX, y: dipY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
