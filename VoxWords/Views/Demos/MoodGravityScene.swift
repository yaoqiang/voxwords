import SpriteKit
import UIKit
import CoreMotion

/// A simple "mood balls" physics scene:
/// - Balls fall from the top with gravity
/// - Collide with each other
/// - Settle into a curved (bowl-like) bottom
/// - Light haptics on impactful contacts
final class MoodGravityScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    struct Config {
        var ballCount: Int = 26
        var ballRadius: CGFloat = 18
        /// Base gravity if device gravity is disabled.
        var gravity: CGVector = .init(dx: 0, dy: -18)

        /// Enable device gravity (tilt) like the reference.
        var usesDeviceGravity: Bool = true
        var gravityStrength: CGFloat = 18
        var gravitySmoothing: CGFloat = 0.18

        /// y of the bowl rim (left/right endpoints).
        var rimY: CGFloat = 84

        /// How deep the bowl dips at center relative to rim.
        var bowlDepth: CGFloat = 70

        /// Resting behavior
        var restitution: CGFloat = 0.18
        var linearDamping: CGFloat = 1.2
        var friction: CGFloat = 0.55

        /// If true, use simplified "burst" haptics during the drop window.
        /// This avoids contact-spam complexity and rate-limit logs.
        var simplifiedDropHaptics: Bool = false

        /// Collision haptics
        var collisionImpulseThreshold: CGFloat = 0.9
        var hapticMaxHz: Double = 12
        /// If true, only ball-ball contacts can generate haptics (prevents boundary rolling buzz).
        var onlyBallBallHaptics: Bool = false
        /// If false, skip the final “settled” haptic.
        var settleHapticEnabled: Bool = true
        /// If true, draw a subtle bowl stroke guide.
        var showsBowlStroke: Bool = true
        /// Gravity deadzone for device tilt (abs(g.x) < deadzone -> treat as 0).
        var deviceGravityDeadzone: CGFloat = 0.08
    }

    private let config: Config

    private enum Category {
        static let ball: UInt32 = 1 << 0
        static let boundary: UInt32 = 1 << 1
    }

    private var lastHapticAt: TimeInterval = 0
    private var stableSince: TimeInterval?
    private var didSettleHaptic = false

    private let motionManager = CMMotionManager()
    private var targetGravity: CGVector = .init(dx: 0, dy: -18)
    private var smoothedGravity: CGVector = .init(dx: 0, dy: -18)

    private var collisionEnergy: CGFloat = 0

    init(size: CGSize, config: Config = .init()) {
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
        physicsWorld.gravity = config.gravity
        physicsWorld.contactDelegate = self

        // Ensure physics is stable/quiet.
        physicsWorld.speed = 1

        rebuildWorld()
        spawnBalls(count: config.ballCount)

        setupGravityInput()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if oldSize != .zero {
            rebuildWorld()
        }
    }

    func reset(ballCount: Int? = nil) {
        removeAllChildren()
        stableSince = nil
        didSettleHaptic = false
        collisionEnergy = 0
        rebuildWorld()
        spawnBalls(count: ballCount ?? config.ballCount)

        setupGravityInput()
    }

    // MARK: - World

    private func rebuildWorld() {
        removeAllChildren()
        stableSince = nil
        didSettleHaptic = false

        // Hard world bounds (including top) so balls can never roll out of the visible area.
        // Since the reference balls "fall inside the header", we also spawn them inside these bounds.
        let inset: CGFloat = 8
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: inset, y: inset, width: max(10, size.width - inset * 2), height: max(10, size.height - inset * 2)))
        self.physicsBody?.isDynamic = false
        self.physicsBody?.friction = config.friction
        self.physicsBody?.categoryBitMask = Category.boundary
        self.physicsBody?.collisionBitMask = Category.ball

        // Edges / bowl
        let bowlPath = makeBowlPath(in: CGSize(width: size.width, height: size.height))
        let boundary = SKNode()
        boundary.physicsBody = SKPhysicsBody(edgeChainFrom: bowlPath)
        boundary.physicsBody?.isDynamic = false
        boundary.physicsBody?.categoryBitMask = Category.boundary
        boundary.physicsBody?.contactTestBitMask = Category.ball
        boundary.physicsBody?.collisionBitMask = Category.ball
        boundary.physicsBody?.friction = config.friction
        addChild(boundary)

        if config.showsBowlStroke {
            // Optional visual guide for the bowl edge (subtle)
            let stroke = SKShapeNode(path: bowlPath)
            stroke.strokeColor = UIColor.white.withAlphaComponent(0.22)
            stroke.lineWidth = 2
            stroke.fillColor = .clear
            stroke.zPosition = 10
            addChild(stroke)
        }
    }

    private func makeBowlPath(in size: CGSize) -> CGPath {
        let w = size.width
        let h = size.height

        // Keep a little margin so balls don't clip.
        let inset: CGFloat = 10
        let leftX: CGFloat = inset
        let rightX: CGFloat = max(inset, w - inset)

        // Rim sits some distance above bottom.
        let rimY = max(40, min(config.rimY, h * 0.45))
        let centerDipY = max(10, rimY - config.bowlDepth)

        let p = UIBezierPath()
        // Only the bowl curve (do NOT close / do NOT add a "ceiling").
        // The outer edgeLoop keeps balls within the container.
        p.move(to: CGPoint(x: leftX, y: rimY))
        p.addQuadCurve(
            to: CGPoint(x: rightX, y: rimY),
            controlPoint: CGPoint(x: w / 2, y: centerDipY)
        )
        return p.cgPath
    }

    // MARK: - Balls

    private func spawnBalls(count: Int) {
        guard count > 0 else { return }

        let w = size.width
        let h = size.height
        let r = config.ballRadius
        let inset: CGFloat = 10

        let palette: [UIColor] = [
            UIColor(red: 0.60, green: 0.87, blue: 0.62, alpha: 1), // green
            UIColor(red: 0.86, green: 0.55, blue: 0.83, alpha: 1), // purple
            UIColor(red: 0.52, green: 0.71, blue: 0.98, alpha: 1), // blue
            UIColor(red: 0.99, green: 0.62, blue: 0.53, alpha: 1)  // coral
        ]

        for i in 0..<count {
            let color = palette[i % palette.count]
            let node = makeBallNode(radius: r, color: color)

            // Spawn INSIDE the container (top bounded), so they "fall" within the header like the reference.
            let x = CGFloat.random(in: (inset + r)...(max(inset + r, w - inset - r)))
            let y = CGFloat.random(in: (h - inset - r - 8)...(max(h - inset - r - 8, h - inset - r - 120)))
            node.position = CGPoint(x: x, y: y)

            // Slight initial horizontal drift to create natural piling.
            node.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -55...55), dy: CGFloat.random(in: -20...0))

            addChild(node)
        }
    }

    private func makeBallNode(radius: CGFloat, color: UIColor) -> SKNode {
        let texture = BallTextureFactory.shared.texture(radius: radius, color: color)
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: radius * 2, height: radius * 2)
        node.zPosition = 5
        node.name = "ball"

        node.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        node.physicsBody?.allowsRotation = true
        node.physicsBody?.restitution = config.restitution
        node.physicsBody?.linearDamping = config.linearDamping
        node.physicsBody?.angularDamping = 1.4
        node.physicsBody?.friction = config.friction
        node.physicsBody?.categoryBitMask = Category.ball
        node.physicsBody?.collisionBitMask = Category.ball | Category.boundary
        node.physicsBody?.contactTestBitMask = Category.boundary | Category.ball

        return node
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)

        // Update gravity from motion (smoothed)
        if config.usesDeviceGravity {
            smoothedGravity = lerp(smoothedGravity, targetGravity, t: config.gravitySmoothing)
            physicsWorld.gravity = smoothedGravity
        } else {
            physicsWorld.gravity = config.gravity
        }

        // Collision-driven haptics, rate-limited
        if collisionEnergy > 0 {
            let minInterval = 1.0 / max(1.0, config.hapticMaxHz)
            if currentTime - lastHapticAt >= minInterval {
                lastHapticAt = currentTime
                let e = min(12, collisionEnergy)
                collisionEnergy = collisionEnergy * 0.45 // decay

                // Map energy -> intensity/sharpness (tuned for "glass balls" bumps)
                let intensity = Float(min(0.90, 0.20 + (e / 12.0) * 0.70))
                Task { @MainActor in
                    // UIImpact is more reliable at high frequency than CoreHaptics patterns.
                    HapticManager.shared.physicsImpact(intensity: CGFloat(intensity))
                }
            }
        }

        // Fire a single “settled” haptic when the whole pile becomes stable.
        guard config.settleHapticEnabled else { return }
        guard didSettleHaptic == false else { return }
        let balls = children.compactMap { $0.physicsBody }.filter { $0.categoryBitMask == Category.ball }
        guard balls.isEmpty == false else { return }

        let maxSpeed = balls.reduce(0.0) { acc, body in
            let v = body.velocity
            return max(acc, hypot(Double(v.dx), Double(v.dy)))
        }

        let stable = maxSpeed < 10
        if stable {
            stableSince = stableSince ?? currentTime
            if let since = stableSince, currentTime - since > 0.35 {
                didSettleHaptic = true
                Task { @MainActor in
                    HapticManager.shared.recordingSuccess()
                }
            }
        } else {
            stableSince = nil
        }
    }

    // MARK: - Contact / Haptics

    func didBegin(_ contact: SKPhysicsContact) {
        // Only react if at least one is a ball.
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        guard (mask & Category.ball) != 0 else { return }

        if config.onlyBallBallHaptics {
            // Require both bodies to be balls.
            guard contact.bodyA.categoryBitMask == Category.ball,
                  contact.bodyB.categoryBitMask == Category.ball else { return }
        }

        // Use impulse to filter small contacts.
        let impulse = contact.collisionImpulse
        guard impulse >= config.collisionImpulseThreshold else { return }

        // Accumulate energy and let update() emit at a stable Hz.
        collisionEnergy += min(10, impulse)
    }

    private func scheduleDropHaptics() {
        // Desired behavior:
        // - total drop window ~2s
        // - between 1s..2s play a soft burst
        run(.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self] in
                guard self != nil else { return }
                Task { @MainActor in
                    HapticManager.shared.moodBallsDropBurst()
                }
            }
        ]))
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Device gravity

    private func setupGravityInput() {
        motionManager.stopDeviceMotionUpdates()

        if config.usesDeviceGravity, motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let g = motion?.gravity else { return }
                // CoreMotion gravity is in device coordinates; SpriteKit uses y-up.
                // In portrait, g.y is ~ -1, which correctly points "down" (negative y).
                let gx = abs(CGFloat(g.x)) < self.config.deviceGravityDeadzone ? 0 : CGFloat(g.x)
                self.targetGravity = CGVector(
                    dx: gx * self.config.gravityStrength,
                    dy: CGFloat(g.y) * self.config.gravityStrength
                )
            }
        } else {
            targetGravity = config.gravity
            smoothedGravity = config.gravity
        }
    }

    private func lerp(_ a: CGVector, _ b: CGVector, t: CGFloat) -> CGVector {
        let tt = max(0, min(1, t))
        return .init(
            dx: a.dx + (b.dx - a.dx) * tt,
            dy: a.dy + (b.dy - a.dy) * tt
        )
    }
}

// MARK: - Glossy ball texture

private final class BallTextureFactory {
    nonisolated(unsafe) static let shared = BallTextureFactory()

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
            let base = color

            // Base circle
            ctx.cgContext.setFillColor(base.cgColor)
            ctx.cgContext.fillEllipse(in: rect)

            // Soft radial highlight (top-left)
            let highlightCenter = CGPoint(x: center.x - CGFloat(r) * 0.35, y: center.y + CGFloat(r) * 0.35)
            let colors = [UIColor.white.withAlphaComponent(0.55).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
                ctx.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: highlightCenter,
                    startRadius: 0,
                    endCenter: highlightCenter,
                    endRadius: CGFloat(r) * 1.2,
                    options: [.drawsAfterEndLocation]
                )
            }

            // Subtle shading (bottom)
            let shadeColors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.22).cgColor] as CFArray
            if let shade = CGGradient(colorsSpace: space, colors: shadeColors, locations: [0.0, 1.0]) {
                ctx.cgContext.drawLinearGradient(
                    shade,
                    start: CGPoint(x: center.x, y: center.y + CGFloat(r) * 0.1),
                    end: CGPoint(x: center.x, y: rect.minY),
                    options: []
                )
            }

            // Thin outer ring like the reference
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.14).cgColor)
            ctx.cgContext.setLineWidth(1)
            ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
        }

        let texture = SKTexture(image: img)
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }
}
