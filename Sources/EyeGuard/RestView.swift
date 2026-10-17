import Cocoa

/// 遮罩内容视图：极简倒计时 + 护眼提示 + 长按紧急退出。
final class RestView: NSView {

    private let countdownLabel = NSTextField(labelWithString: "")
    private let hintLabel      = NSTextField(labelWithString: "")
    private let subHintLabel   = NSTextField(labelWithString: "")
    private let holdRing       = HoldRingView()
    private let holdTipLabel   = NSTextField(labelWithString: "")

    private var remaining: TimeInterval = 0
    private var totalRest: TimeInterval = 0
    private var timer: Timer?

    /// 休息自然结束时回调
    var onFinished: (() -> Void)?
    /// 长按紧急退出达成时回调
    var onEmergencyExit: (() -> Void)?

    init(frame: NSRect, screen: NSScreen) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    // MARK: - UI 构建

    private func buildUI() {
        // 倒计时数字：极简、超大、等宽
        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 128, weight: .thin)
        countdownLabel.textColor = NSColor.white.withAlphaComponent(0.95)
        countdownLabel.alignment = .center
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(countdownLabel)

        // 主提示
        hintLabel.font = NSFont.systemFont(ofSize: 24, weight: .light)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.62)
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)

        // 副提示
        subHintLabel.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        subHintLabel.textColor = NSColor.white.withAlphaComponent(0.34)
        subHintLabel.alignment = .center
        subHintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subHintLabel)

        // 长按进度环
        holdRing.translatesAutoresizingMaskIntoConstraints = false
        addSubview(holdRing)

        holdTipLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        holdTipLabel.textColor = NSColor.white.withAlphaComponent(0.22)
        holdTipLabel.alignment = .center
        holdTipLabel.stringValue = "长按此处 \(Config.shared.holdSeconds) 秒可紧急退出"
        holdTipLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(holdTipLabel)

        NSLayoutConstraint.activate([
            countdownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),

            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: countdownLabel.bottomAnchor, constant: 18),
            hintLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.72),

            subHintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subHintLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
            subHintLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.72),

            holdRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            holdRing.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -72),
            holdRing.widthAnchor.constraint(equalToConstant: 46),
            holdRing.heightAnchor.constraint(equalToConstant: 46),

            holdTipLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            holdTipLabel.topAnchor.constraint(equalTo: holdRing.bottomAnchor, constant: 10)
        ])

        hintLabel.stringValue = Self.randomHint()
        subHintLabel.stringValue = "看向 6 米以外，让睫状肌放松"

        holdRing.onComplete = { [weak self] in
            self?.onEmergencyExit?()
        }
    }

    // MARK: - 启动倒计时

    func start(seconds: TimeInterval) {
        totalRest = seconds
        remaining = seconds
        updateCountdown()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remaining -= 1
            if self.remaining <= 0 {
                self.remaining = 0
                self.updateCountdown()
                self.timer?.invalidate()
                self.timer = nil
                self.onFinished?()
            } else {
                self.updateCountdown()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        holdRing.reset()
    }

    private func updateCountdown() {
        let secs = Int(remaining.rounded())
        let m = secs / 60
        let s = secs % 60
        countdownLabel.stringValue = String(format: "%02d:%02d", m, s)
    }

    // MARK: - 护眼提示文案

    private static func randomHint() -> String {
        let hints = [
            "起身走动一下",
            "远眺窗外，放松眼睛",
            "闭上眼睛休息片刻",
            "转动眼球，缓解疲劳",
            "喝杯水，顺便活动肩颈",
            "深呼吸，让眼睛和大脑都歇一歇"
        ]
        return hints.randomElement() ?? "休息一下"
    }
}

// MARK: - 长按进度环

/// 环形进度控件：按住鼠标/触控板时开始累计进度，松手即清零。
/// 这是唯一的「紧急退出」通道，故意设计为需要持续按住，避免误触。
final class HoldRingView: NSView {

    private var progress: CGFloat = 0
    private var timer: Timer?
    private let totalSeconds: CGFloat = CGFloat(Config.shared.holdSeconds)

    /// 长按达成回调
    var onComplete: (() -> Void)?

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 3

        // 底环
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        ctx.setLineWidth(2.5)
        ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // 进度环（从 12 点方向顺时针）
        if progress > 0 {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
            ctx.setLineWidth(2.5)
            ctx.setLineCap(.round)
            let start = CGFloat.pi / 2
            let end = start - progress * .pi * 2
            ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
            ctx.strokePath()
        }

        // 中心圆点
        ctx.setFillColor(NSColor.white.withAlphaComponent(progress > 0 ? 0.7 : 0.28).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
    }

    override func mouseDown(with event: NSEvent) {
        startHolding()
    }

    override func mouseUp(with event: NSEvent) {
        cancelHolding()
    }

    override func mouseExited(with event: NSEvent) {
        cancelHolding()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        ))
    }

    private func startHolding() {
        guard timer == nil else { return }
        progress = 0
        let step: TimeInterval = 1.0 / 30.0
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.progress += CGFloat(step) / self.totalSeconds
            if self.progress >= 1 {
                self.progress = 1
                self.needsDisplay = true
                self.cancelHolding()
                self.onComplete?()
                return
            }
            self.needsDisplay = true
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    private func cancelHolding() {
        timer?.invalidate()
        timer = nil
        if progress < 1 {
            progress = 0
            needsDisplay = true
        }
    }

    func reset() {
        cancelHolding()
        progress = 0
        needsDisplay = true
    }
}
