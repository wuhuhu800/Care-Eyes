import Cocoa

/// 休息调度器：负责工作计时、触发遮罩、管理多屏窗口生命周期。
final class RestScheduler {

    /// 状态变化时通知外部（菜单栏刷新）
    var onStateChange: (() -> Void)?

    private var workTimer: Timer?
    private var remainingWork: TimeInterval = 0
    private var windows: [RestWindow] = []
    private var isRestingNow = false

    /// 屏幕参数变化（插拔显示器）时重建遮罩
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildWindowsIfResting()
        }
    }

    deinit {
        if let o = screenObserver { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - 对外状态

    var isResting: Bool { isRestingNow }

    /// 距离下次休息的剩余秒数（休息中返回 0）
    var remainingWorkSeconds: Int { isRestingNow ? 0 : Int(remainingWork.rounded()) }

    // MARK: - 启动 / 停止

    /// 开始（或重启）工作计时，对应配置的 workMinutes
    func restart() {
        guard Config.shared.enabled else {
            stopWorkTimer()
            onStateChange?()
            return
        }
        guard !isRestingNow else { return }

        remainingWork = Config.shared.workSeconds
        stopWorkTimer()

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingWork -= 1
            if self.remainingWork <= 0 {
                self.stopWorkTimer()
                self.beginRest()
            } else {
                self.onStateChange?()
            }
        }
        workTimer = t
        RunLoop.main.add(t, forMode: .common)
        onStateChange?()
    }

    /// 暂停计时（不清零，保留剩余时间）
    func pause() {
        stopWorkTimer()
        onStateChange?()
    }

    /// 从暂停恢复
    func resume() {
        guard !isRestingNow, Config.shared.enabled else { return }
        guard remainingWork > 0 else { restart(); return }
        startWorkTimerOnly()
    }

    private func startWorkTimerOnly() {
        stopWorkTimer()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingWork -= 1
            if self.remainingWork <= 0 {
                self.stopWorkTimer()
                self.beginRest()
            } else {
                self.onStateChange?()
            }
        }
        workTimer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func stopWorkTimer() {
        workTimer?.invalidate()
        workTimer = nil
    }

    // MARK: - 休息触发

    /// 立即进入休息（手动或自动）
    func beginRest() {
        guard !isRestingNow else { return }
        isRestingNow = true
        stopWorkTimer()
        buildWindows()
        onStateChange?()
    }

    private func buildWindows() {
        teardownWindows()
        for screen in NSScreen.screens {
            let w = RestWindow(screen: screen)

            guard let view = w.contentView as? RestView else { continue }
            view.onFinished = { [weak self] in
                self?.endRest()
            }
            view.onEmergencyExit = { [weak self] in
                self?.emergencyExit()
            }
            // 让遮罩强制获得焦点，阻止键盘输入穿透到别的应用
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
            view.start(seconds: Config.shared.restSeconds)
            windows.append(w)
        }
        // 激活本应用，减少切换到其它应用的可能
        NSApp.activate(ignoringOtherApps: true)
    }

    private func rebuildWindowsIfResting() {
        guard isRestingNow else { return }
        buildWindows()
    }

    private func teardownWindows() {
        for w in windows {
            if let v = w.contentView as? RestView { v.stop() }
            w.orderOut(nil)
            w.contentView = nil
        }
        windows.removeAll()
    }

    /// 休息正常结束
    private func endRest() {
        teardownWindows()
        isRestingNow = false
        remainingWork = Config.shared.workSeconds
        onStateChange?()
        if Config.shared.enabled { restart() }
    }

    /// 长按紧急退出：跳过本次休息并继续计时
    private func emergencyExit() {
        teardownWindows()
        isRestingNow = false
        remainingWork = Config.shared.workSeconds
        onStateChange?()
        if Config.shared.enabled { restart() }
    }
}
