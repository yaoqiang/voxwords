import SwiftUI
import SpriteKit
import SwiftData
import UIKit
import CoreMotion

// MARK: - Home

struct HomeView: View {
    @Binding var selectedDay: Date
    let entries: [WordEntry]
    let isActive: Bool
    let zoomNamespace: Namespace.ID
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

    @State private var focusedDay: Date? = nil

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        heroArea

                        ForEach(groupedByMonth, id: \.month) { section in
                            monthSection(section.month, days: section.days)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
                .onChange(of: selectedDay) { _, newValue in
                    guard isActive else { return }
                    let key = Calendar.current.startOfDay(for: newValue)
                    focusedDay = key
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        proxy.scrollTo(key, anchor: .center)
                    }
                }
                .onChange(of: isActive) { _, newValue in
                    guard newValue else { return }
                    let key = Calendar.current.startOfDay(for: selectedDay)
                    focusedDay = key
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                            proxy.scrollTo(key, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                // Fun "stir the ocean" button (purely visual, kid-friendly).
                Button {
                    HapticManager.shared.softImpact()
                    NotificationCenter.default.post(name: .voxWordsOceanStir, object: nil)
                } label: {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.30), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
                        .overlay(
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.70))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    HapticManager.shared.selectionChanged()
                    onOpenSettings()
                } label: {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.30), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
                        .overlay(
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.70))
                        )
                }
                .buttonStyle(.plain)
            }

            // Subtle centered brand mark (keeps the page anchored).
            Text("VoxWords")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule(style: .continuous).stroke(VoxTheme.Glass.stroke, lineWidth: VoxTheme.Glass.strokeWidth))
                )
                .allowsHitTesting(false)
        }
        .padding(.horizontal, VoxTheme.Dimensions.largePadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var heroArea: some View {
        VStack(spacing: 14) {
            WordsOceanCard(wordCount: max(1, totalCount), isActive: isActive)
                .frame(height: 190)
        }
        .padding(.bottom, 6)
    }

    private func monthSection(_ month: Date, days: [Date]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(month, format: .dateTime.month(.wide))
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(.primary.opacity(0.92))

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
                .id(key)
                .matchedTransitionSource(id: key, in: zoomNamespace)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.primary.opacity((focusedDay == key) ? 0.18 : 0.0), lineWidth: 2)
                        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: focusedDay)
                )
                .scaleEffect((focusedDay == key) ? 1.01 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.84), value: focusedDay)
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Words Ocean (kid-friendly)

extension Notification.Name {
    static let voxWordsOceanStir = Notification.Name("voxWordsOceanStir")
}

struct WordsOceanCard: View {
    let wordCount: Int
    let isActive: Bool

    @State private var seed: UInt64 = 1
    @State private var phase: Double = 0
    @State private var resetToken = UUID()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    drawOcean(in: ctx, size: size, time: t)
                }
                .allowsHitTesting(false)
            }

            // SpriteKit "ocean bubbles" with light gravity + haptics.
            // Symbolic mapping:
            // - more learned words -> more bubbles
            // - water level rises with words (Canvas)
            GeometryReader { proxy in
                let size = proxy.size
                if isActive {
                    let wc = max(1, wordCount)
                    let level = min(0.86, max(0.38, 0.38 + log(Double(wc) + 1) / 6.0))
                    let waterTopFromTop = size.height * CGFloat(1 - level)

                    // Base bubbles: keep it clean (avoid clutter) and use "pearls" for milestones.
                    let bubbleCount = min(26, max(10, Int(8 + log(Double(wc) + 1) * 7)))
                    let bubbleRadius = CGFloat(max(7.5, min(11.5, 12.0 - CGFloat(bubbleCount) * 0.08)))
                    let pearlCount = min(6, max(0, Int(log(Double(wc) + 1) * 1.6) - 1))

                    let scene = OceanGravityBubbleScene(
                        size: size,
                        config: .init(
                            bubbleCount: bubbleCount,
                            bubbleRadius: bubbleRadius,
                            pearlCount: pearlCount,
                            // Use real "downward" gravity + tilt-driven horizontal drift.
                            // This avoids the anti-gravity look (all bubbles at the top).
                            gravity: .init(dx: 0, dy: -8.5),
                            // Keep the bowl very low so bubbles don't form a mid-line.
                            bowlRimY: size.height * 0.12,
                            bowlDepth: min(22, size.height * 0.10),
                            waterTopFromTop: waterTopFromTop,
                            usesDeviceTilt: true,
                            tiltStrength: 8.5,
                            linearDamping: 0.95,
                            restitution: 0.30,
                            seed: seed
                        )
                    )
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .id(resetToken)
                        .background(Color.clear)
                        .allowsHitTesting(false)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .opacity(0.80)
                } else {
                    Color.clear
                }
            }
        }
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            guard isActive else { return }
            HapticManager.shared.softImpact()
            NotificationCenter.default.post(name: .voxWordsOceanStir, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .voxWordsOceanStir)) { _ in
            guard isActive else { return }
            // Change seed to reshuffle bubble layout.
            seed = seed &+ 0x9E3779B97F4A7C15
            phase += 1
            resetToken = UUID()
        }
    }

    private func drawOcean(in ctx: GraphicsContext, size: CGSize, time t: TimeInterval) {
        let w = size.width
        let h = size.height

        // Water level grows with learning volume, capped for aesthetics.
        let wc = max(1, wordCount)
        let level = min(0.86, max(0.38, 0.38 + log(Double(wc) + 1) / 6.0))
        let waterTopY = h * CGFloat(1 - level)

        // Background gradient (soft, kid-friendly).
        let bg = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: 28)
        ctx.fill(
            bg,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.55),
                    Color(red: 0.98, green: 0.97, blue: 0.94).opacity(0.35)
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        // Water body (smaller "basin" than before).
        var water = Path()
        water.move(to: CGPoint(x: 0, y: waterTopY))
        let waveAmp: CGFloat = 8
        let waveLen: CGFloat = max(120, w * 0.55)
        for x in stride(from: CGFloat(0), through: w, by: 8) {
            let y = waterTopY
                + sin((x / waveLen) * .pi * 2 + CGFloat(t) * 1.1 + CGFloat(phase) * 0.9) * waveAmp
            water.addLine(to: CGPoint(x: x, y: y))
        }
        water.addLine(to: CGPoint(x: w, y: h))
        water.addLine(to: CGPoint(x: 0, y: h))
        water.closeSubpath()

        ctx.fill(
            water,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.92, green: 0.96, blue: 0.98).opacity(0.85),
                    Color(red: 0.86, green: 0.92, blue: 0.98).opacity(0.92)
                ]),
                startPoint: CGPoint(x: 0, y: waterTopY),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        // Layer 2 (Canvas): subtle "plankton" particles in water (more words => slightly denser).
        // SpriteKit renders the main bubbles, so Canvas stays calm/clean.
        let particleCount = min(78, max(18, Int(14 + log(Double(wc) + 1) * 18)))
        var rng = SeededRNG(seed: UInt64(wc) &* 0x9E3779B97F4A7C15 &+ UInt64(t.rounded(.down)))
        for i in 0..<particleCount {
            let x = CGFloat(rng.nextDouble()) * w
            let yBase = waterTopY + CGFloat(rng.nextDouble()) * (h - waterTopY)
            let drift = sin(CGFloat(t) * 0.7 + CGFloat(i) * 0.9) * 6
            let y = min(h, max(waterTopY + 8, yBase + drift))
            let r = CGFloat(0.8 + rng.nextDouble() * 1.6)
            let a = 0.05 + rng.nextDouble() * 0.08
            let p = Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2))
            ctx.fill(p, with: .color(Color.white.opacity(a)))
        }
    }

    private func hash(_ i: Int) -> Int {
        // Deterministic hash based on current seed.
        var x = UInt64(bitPattern: Int64(i)) &+ seed
        x &+= 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x = x ^ (x >> 31)
        return Int(truncatingIfNeeded: x)
    }
}

// MARK: - Small deterministic RNG (stable particles)
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x123456789ABCDEF : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

// MARK: - SpriteKit bubbles (gravity + haptics)

private final class OceanGravityBubbleScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    struct Config {
        var bubbleCount: Int
        var bubbleRadius: CGFloat
        var pearlCount: Int
        var gravity: CGVector
        var bowlRimY: CGFloat
        var bowlDepth: CGFloat
        var waterTopFromTop: CGFloat
        var usesDeviceTilt: Bool
        var tiltStrength: CGFloat
        var linearDamping: CGFloat
        var restitution: CGFloat
        var seed: UInt64
    }

    private let config: Config
    // Lazily created to avoid CoreMotion logs at cold start.
    private var motion: CMMotionManager?
    private var stirObserver: NSObjectProtocol?
    private var smoothedGravity: CGVector = .zero
    private var lastHapticAt: TimeInterval = 0
    private let haptic = UIImpactFeedbackGenerator(style: .soft)
    private var bubbleNodes: [SKSpriteNode] = []
    private var cachedWaterTopY: CGFloat = 0
    private static let bubbleCategory: UInt32 = 1 << 1
    private static let boundaryCategory: UInt32 = 1 << 2

    init(size: CGSize, config: Config) {
        self.config = config
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.allowsTransparency = true
        physicsWorld.gravity = config.gravity
        physicsWorld.speed = 1
        physicsWorld.contactDelegate = self
        haptic.prepare()

        rebuildWorld()
        spawnBubbles()
        // Start tilt only after the user shows intent (stir), and after a longer grace period.
        // This keeps cold-start logs quieter, especially if we auto-navigate away from Home.
        stirObserver = NotificationCenter.default.addObserver(
            forName: .voxWordsOceanStir,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.startTiltIfNeeded()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            Task { @MainActor [weak self] in
                self?.startTiltIfNeeded()
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if oldSize != .zero {
            rebuildWorld()
        }
    }

    private func rebuildWorld() {
        removeAllChildren()

        let inset: CGFloat = 10
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(
            x: inset,
            y: inset,
            width: max(10, size.width - inset * 2),
            height: max(10, size.height - inset * 2)
        ))
        physicsBody?.isDynamic = false
        physicsBody?.friction = 0.0
        physicsBody?.restitution = 0.65

        // A shallow bowl near the bottom.
        let bowlPath = makeBowlPath(size: size)
        let bowl = SKNode()
        bowl.name = "bowl"
        bowl.physicsBody = SKPhysicsBody(edgeChainFrom: bowlPath)
        bowl.physicsBody?.isDynamic = false
        bowl.physicsBody?.friction = 0.35
        bowl.physicsBody?.restitution = 0.15
        bowl.physicsBody?.categoryBitMask = Self.boundaryCategory
        bowl.physicsBody?.contactTestBitMask = Self.bubbleCategory
        bowl.physicsBody?.collisionBitMask = Self.bubbleCategory
        addChild(bowl)

        // Water-top boundary: keep bubbles inside the water region.
        // SwiftUI y grows down; SpriteKit y grows up.
        let waterTopY = max(12, min(size.height - 12, size.height - config.waterTopFromTop))
        cachedWaterTopY = waterTopY
        let waterTop = SKNode()
        waterTop.name = "waterTop"
        waterTop.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: inset, y: waterTopY), to: CGPoint(x: size.width - inset, y: waterTopY))
        waterTop.physicsBody?.isDynamic = false
        waterTop.physicsBody?.friction = 0
        waterTop.physicsBody?.restitution = 0.20
        waterTop.physicsBody?.categoryBitMask = Self.boundaryCategory
        waterTop.physicsBody?.contactTestBitMask = Self.bubbleCategory
        waterTop.physicsBody?.collisionBitMask = Self.bubbleCategory
        addChild(waterTop)
    }

    private func spawnBubbles() {
        bubbleNodes.removeAll(keepingCapacity: true)
        let r = max(8, config.bubbleRadius)
        let inset: CGFloat = 14
        let w = size.width
        let h = size.height
        // SwiftUI waterTopFromTop -> SpriteKit water region height
        let waterTopY = max(inset + r, min(h - inset - r, h - config.waterTopFromTop))

        for i in 0..<max(1, config.bubbleCount) {
            let color = bubbleColor(i: i)
            let node = SKSpriteNode(texture: OceanBubbleTextureFactory.shared.texture(radius: r, color: color))
            node.size = CGSize(width: r * 2, height: r * 2)
            node.alpha = 0.95
            node.zPosition = 3

            let x = CGFloat.random(in: (inset + r)...(max(inset + r, w - inset - r)))
            // Spawn inside water region only.
            let y = CGFloat.random(in: (inset + r)...(max(inset + r, waterTopY - r - 6)))
            node.position = CGPoint(x: x, y: y)

            node.physicsBody = SKPhysicsBody(circleOfRadius: r)
            node.physicsBody?.allowsRotation = false
            node.physicsBody?.friction = 0.25
            node.physicsBody?.restitution = config.restitution
            node.physicsBody?.linearDamping = config.linearDamping
            node.physicsBody?.angularDamping = 99
            node.physicsBody?.categoryBitMask = Self.bubbleCategory
            node.physicsBody?.contactTestBitMask = Self.bubbleCategory | Self.boundaryCategory
            node.physicsBody?.collisionBitMask = Self.bubbleCategory | Self.boundaryCategory
            node.name = "bubble"

            // Small initial drift so it feels alive before settling.
            let angle = CGFloat(hash(i)) / 1024.0 * .pi * 2
            let speed: CGFloat = 45 * (0.72 + CGFloat(abs(hash(i + 17)) % 50) / 100.0)
            node.physicsBody?.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed * 0.6)

            addChild(node)
            bubbleNodes.append(node)
        }

        // Layer 3: Milestone "pearls" (fewer, larger, symbolic richness).
        let pr = max(r + 6, min(r + 12, r * 1.75))
        for i in 0..<max(0, config.pearlCount) {
            let node = SKSpriteNode(texture: OceanBubbleTextureFactory.shared.texture(radius: pr, color: UIColor(white: 1.0, alpha: 1.0)))
            node.size = CGSize(width: pr * 2, height: pr * 2)
            node.alpha = 0.55
            node.zPosition = 2

            let x = CGFloat.random(in: (inset + pr)...(max(inset + pr, w - inset - pr)))
            let y = CGFloat.random(in: (inset + pr)...(max(inset + pr, waterTopY - pr - 10)))
            node.position = CGPoint(x: x, y: y)

            node.physicsBody = SKPhysicsBody(circleOfRadius: pr)
            node.physicsBody?.allowsRotation = false
            node.physicsBody?.friction = 0.12
            node.physicsBody?.restitution = min(0.34, config.restitution + 0.06)
            node.physicsBody?.linearDamping = max(0.75, config.linearDamping - 0.15)
            node.physicsBody?.angularDamping = 99
            node.physicsBody?.categoryBitMask = Self.bubbleCategory
            node.physicsBody?.contactTestBitMask = Self.bubbleCategory | Self.boundaryCategory
            node.physicsBody?.collisionBitMask = Self.bubbleCategory | Self.boundaryCategory
            node.name = "pearl"

            let angle = CGFloat(hash(10_000 + i)) / 1024.0 * .pi * 2
            let speed: CGFloat = 26 * (0.70 + CGFloat(abs(hash(i + 91)) % 50) / 100.0)
            node.physicsBody?.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed * 0.8)

            addChild(node)
            bubbleNodes.append(node)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)

        // Gentle "water current": follows tilt with a soft swirl.
        let gx = physicsWorld.gravity.dx
        let currentX = max(-18, min(18, gx * 1.2))
        let swirl = sin(currentTime * 1.1) * 7

        for (idx, node) in bubbleNodes.enumerated() {
            guard let body = node.physicsBody else { continue }
            let t = CGFloat(idx) * 0.7 + CGFloat(currentTime) * 0.9
            let jitter = CGVector(dx: cos(t) * 1.6, dy: sin(t * 1.2) * 1.2)
            body.applyForce(CGVector(dx: currentX + swirl + jitter.dx, dy: jitter.dy))
        }
    }

    private func makeBowlPath(size: CGSize) -> CGPath {
        let w = size.width
        let inset: CGFloat = 12
        let leftX = inset
        let rightX = max(inset, w - inset)

        let rimY = max(40, min(config.bowlRimY, size.height * 0.55))
        let dipY = max(14, rimY - config.bowlDepth)

        let p = UIBezierPath()
        p.move(to: CGPoint(x: leftX, y: rimY))
        p.addQuadCurve(to: CGPoint(x: rightX, y: rimY), controlPoint: CGPoint(x: w / 2, y: dipY))
        return p.cgPath
    }

    private func startTiltIfNeeded() {
        guard config.usesDeviceTilt else { return }
        let m = motion ?? CMMotionManager()
        motion = m
        guard m.isDeviceMotionAvailable else { return }
        m.deviceMotionUpdateInterval = 1.0 / 60.0
        m.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            // Dead-zone: when device is flat, keep dx at 0 (prevents left↔right oscillation).
            let rawX = CGFloat(g.x)
            let deadZone: CGFloat = 0.06
            let stableX: CGFloat = abs(rawX) < deadZone ? 0 : rawX
            let gx = max(-12, min(12, stableX * self.config.tiltStrength))
            let target = CGVector(dx: gx, dy: self.config.gravity.dy)
            self.smoothedGravity = CGVector(
                dx: self.smoothedGravity.dx + (target.dx - self.smoothedGravity.dx) * 0.10,
                dy: self.smoothedGravity.dy + (target.dy - self.smoothedGravity.dy) * 0.10
            )
            self.physicsWorld.gravity = self.smoothedGravity
        }
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        motion?.stopDeviceMotionUpdates()
        if let obs = stirObserver {
            NotificationCenter.default.removeObserver(obs)
            stirObserver = nil
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        // Haptics: impulse-based, throttled (natural feel).
        let now = CACurrentMediaTime()
        let a = contact.bodyA
        let b = contact.bodyB

        let isBubbleA = a.categoryBitMask == Self.bubbleCategory
        let isBubbleB = b.categoryBitMask == Self.bubbleCategory
        let isBoundaryA = a.categoryBitMask == Self.boundaryCategory
        let isBoundaryB = b.categoryBitMask == Self.boundaryCategory

        let impulse = contact.collisionImpulse

        // Bubble hits water surface: respawn so the scene stays airy/clean.
        if (isBubbleA && isBoundaryB) || (isBubbleB && isBoundaryA) {
            let bubbleNode = (isBubbleA ? a.node : b.node) as? SKSpriteNode
            let boundaryNode = (isBoundaryA ? a.node : b.node)

            if boundaryNode?.name == "waterTop", let bubbleNode {
                respawnBubble(bubbleNode)
                softHaptic(now: now, impulse: impulse, baseThreshold: 0.35)
                return
            }

            // Other boundary hits (bowl/edges) get a tiny tick occasionally.
            softHaptic(now: now, impulse: impulse, baseThreshold: 0.55)
            return
        }

        // Bubble-bubble collisions.
        guard isBubbleA && isBubbleB else { return }
        softHaptic(now: now, impulse: impulse, baseThreshold: 0.75)
    }

    private func respawnBubble(_ node: SKSpriteNode) {
        guard let body = node.physicsBody else { return }
        let r = node.size.width * 0.5
        let inset: CGFloat = 14
        let w = size.width
        let bottomY = inset + r + 6
        let topY = max(bottomY + 10, cachedWaterTopY - r - 10)

        node.position = CGPoint(
            x: CGFloat.random(in: (inset + r)...(max(inset + r, w - inset - r))),
            y: CGFloat.random(in: bottomY...min(bottomY + 26, topY))
        )
        let vx = CGFloat.random(in: -40...40)
        let vy = CGFloat.random(in: 40...110)
        body.velocity = CGVector(dx: vx, dy: vy)
    }

    private func softHaptic(now: TimeInterval, impulse: CGFloat, baseThreshold: CGFloat) {
        guard impulse > baseThreshold else { return }
        // Slightly adaptive interval: allow stronger impacts a bit more often.
        let minInterval = max(0.09, 0.18 - min(0.07, Double((impulse - baseThreshold) / 14.0)))
        if now - lastHapticAt < minInterval { return }
        lastHapticAt = now

        let normalized = max(0, min(1, (impulse - baseThreshold) / 10.0))
        let intensity = min(0.75, max(0.12, 0.18 + normalized * 0.55))
        haptic.impactOccurred(intensity: CGFloat(intensity))
        haptic.prepare()
    }

    private func bubbleColor(i: Int) -> UIColor {
        let palette: [UIColor] = [
            UIColor(red: 0.60, green: 0.87, blue: 0.62, alpha: 1),
            UIColor(red: 0.86, green: 0.55, blue: 0.83, alpha: 1),
            UIColor(red: 0.52, green: 0.71, blue: 0.98, alpha: 1),
            UIColor(red: 0.99, green: 0.62, blue: 0.53, alpha: 1)
        ]
        return palette[i % palette.count]
    }

    private func hash(_ i: Int) -> Int {
        var x = UInt64(bitPattern: Int64(i)) &+ config.seed
        x &+= 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x = x ^ (x >> 31)
        return Int(truncatingIfNeeded: x)
    }
}

private final class OceanBubbleTextureFactory {
    nonisolated(unsafe) static let shared = OceanBubbleTextureFactory()

    private struct Key: Hashable {
        let r: Int
        let rgba: UInt32
    }

    private var cache: [Key: SKTexture] = [:]

    func texture(radius: CGFloat, color: UIColor) -> SKTexture {
        let r = max(8, Int(radius.rounded()))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgba = (UInt32(red * 255) << 24) | (UInt32(green * 255) << 16) | (UInt32(blue * 255) << 8) | UInt32(alpha * 255)
        let key = Key(r: r, rgba: rgba)
        if let t = cache[key] { return t }

        let size = CGSize(width: r * 2, height: r * 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)

            // Base
            ctx.cgContext.setFillColor(color.withAlphaComponent(0.95).cgColor)
            ctx.cgContext.fillEllipse(in: rect)

            // Highlight (top-left)
            let highlightCenter = CGPoint(x: center.x - CGFloat(r) * 0.35, y: center.y - CGFloat(r) * 0.35)
            let colors = [
                UIColor.white.withAlphaComponent(0.45).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
                ctx.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: highlightCenter,
                    startRadius: 0,
                    endCenter: highlightCenter,
                    endRadius: CGFloat(r) * 1.25,
                    options: [.drawsAfterEndLocation]
                )
            }

            // Soft edge ring
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            ctx.cgContext.setLineWidth(1)
            ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
        }

        let texture = SKTexture(image: img)
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }
}

struct CapDayCard: View {
    let day: Date
    let count: Int
    let sampleWords: [String]
    @Environment(\.colorScheme) private var colorScheme

    private var bg: Color {
        let isDark = (colorScheme == .dark)
        if count == 0 { return isDark ? Color.white : Color.black }
        if count < 4 { return Color(red: 0.93, green: 0.90, blue: 0.92) }
        if count < 10 { return Color(red: 0.88, green: 0.84, blue: 0.90) }
        return Color(red: 0.84, green: 0.80, blue: 0.90)
    }

    var body: some View {
        let isDark = (colorScheme == .dark)
        VStack(alignment: .leading, spacing: 12) {
            Text(day, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(.primary)

            Text(count == 0
                 ? String(localized: "home.daycard.empty")
                 : String.localizedStringWithFormat(String(localized: "common.words_count"), count))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                ForEach(Array(sampleWords.prefix(4).enumerated()), id: \.offset) { _, w in
                    Text(String(w.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(VoxTheme.Glass.stroke, lineWidth: VoxTheme.Glass.strokeWidth)
                                )
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
                .fill(.ultraThinMaterial)
                // subtle tint per activity level
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(bg.opacity(isDark ? (count == 0 ? 0.06 : 0.12) : (count == 0 ? 0.10 : 0.22)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(VoxTheme.Glass.stroke, lineWidth: VoxTheme.Glass.strokeWidth)
                )
                .shadow(color: VoxTheme.Glass.shadow, radius: 16, x: 0, y: 10)
        )
    }
}

// Removed: WordsGravityCard + bowl shape (replaced by WordsOceanCard)
