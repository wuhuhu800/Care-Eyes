import Cocoa
import ServiceManagement

/// 应用主控制器：菜单栏图标 + 状态显示 + 各类操作入口。
final class AppController: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let scheduler = RestScheduler()
    private let settingsWC = SettingsWindowController()
    private var statusTimer: Timer?

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        scheduler.onStateChange = { [weak self] in
            self?.refreshMenu()
        }

        settingsWC.onSave = { [weak self] in
            self?.scheduler.restart()
        }

        // 每秒刷新菜单栏标题（显示倒计时）
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshMenu()
        }
        statusTimer = t
        RunLoop.main.add(t, forMode: .common)

        if Config.shared.enabled {
            scheduler.restart()
        }
        refreshMenu()

        // 菜单栏应用默认没有主窗口，启动时给出一次明确反馈，避免用户误以为没有启动。
        showLaunchFeedback()
    }

    /// 应用已经在运行时再次双击 .app：直接打开设置窗口。
    /// 这是菜单栏应用必须提供的“第二次启动”行为，否则用户会感觉双击没有反应。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWC.showAndFocus()
        return true
    }

    /// 单例应用：关闭设置窗口后不退出
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func showLaunchFeedback() {
        // 设计取舍：不依赖系统通知权限，避免用户在「通知」里关掉后失去全部反馈。
        // 改为短暂显示一个无边框浮层，2 秒后自动淡出，既不阻断操作，也一定有反馈。
        guard let screen = NSScreen.main else { return }

        let size = NSSize(width: 380, height: 74)
        let origin = NSPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 24
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.11, alpha: 0.94).cgColor
        container.layer?.cornerRadius = 14

        let title = NSTextField(labelWithString: "护眼强制休息已启动")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .white
        title.frame = NSRect(x: 18, y: 42, width: size.width - 36, height: 18)

        let detail = NSTextField(labelWithString: "工作 \(Config.shared.workMinutes) 分钟后休息 \(Config.shared.restMinutes) 分钟 · 菜单栏可见倒计时")
        detail.font = NSFont.systemFont(ofSize: 11.5)
        detail.textColor = NSColor.white.withAlphaComponent(0.65)
        detail.frame = NSRect(x: 18, y: 22, width: size.width - 36, height: 16)

        container.addSubview(title)
        container.addSubview(detail)
        panel.contentView = container
        panel.orderFrontRegardless()

        // 2.4 秒后淡出并释放
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.45
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // 使用闭眼图标，与“休息”语义一致；较高优先级便于在拥挤的菜单栏中找到
            let img = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "护眼强制休息")
                ?? NSImage(systemSymbolName: "eye", accessibilityDescription: "护眼强制休息")
            img?.isTemplate = true
            button.image = img
            button.imagePosition = .imageLeading
            button.title = ""
            button.toolTip = "护眼强制休息 · 点击查看剩余时间与设置"
        }
    }

    private func refreshMenu() {
        let menu = NSMenu()
        let c = Config.shared

        // 状态行
        let stateText: String
        if !c.enabled {
            stateText = "⏸ 已暂停"
        } else if scheduler.isResting {
            stateText = "😴 休息中"
        } else {
            let s = scheduler.remainingWorkSeconds
            stateText = String(format: "👀 距下次休息 %02d:%02d", s / 60, s % 60)
        }
        let stateItem = NSMenuItem(title: stateText, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        // 菜单栏标题同步倒计时
        if c.enabled && !scheduler.isResting {
            let s = scheduler.remainingWorkSeconds
            statusItem.button?.title = String(format: " %02d:%02d", s / 60, s % 60)
        } else {
            statusItem.button?.title = ""
        }

        menu.addItem(.separator())

        // 暂停 / 恢复
        if c.enabled {
            menu.addItem(makeItem("暂停计时", #selector(togglePause), "p"))
        } else {
            menu.addItem(makeItem("恢复计时", #selector(togglePause), "p"))
        }

        // 立即休息
        let restItem = makeItem("立即休息", #selector(restNow), "r")
        restItem.isEnabled = !scheduler.isResting
        menu.addItem(restItem)

        menu.addItem(.separator())

        // 设置
        menu.addItem(makeItem("设置…", #selector(openSettings), ","))

        // 开机自启
        let launchItem = makeItem("开机自动启动", #selector(toggleLaunchAtLogin), "")
        launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        // 退出
        let quitItem = makeItem("退出", #selector(quitApp), "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeItem(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - 动作

    @objc private func togglePause() {
        let c = Config.shared
        if c.enabled {
            c.enabled = false
            scheduler.pause()
        } else {
            c.enabled = true
            scheduler.restart()
        }
        refreshMenu()
    }

    @objc private func restNow() {
        scheduler.beginRest()
    }

    @objc private func openSettings() {
        settingsWC.showAndFocus()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - 开机自启

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // macOS 12 及更早：用登录项 plist 判断
            let path = ("~/Library/LaunchAgents/com.xiaofeixia.eyeguard.plist" as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: path)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            disableLaunchAtLogin()
        } else {
            enableLaunchAtLogin()
        }
        refreshMenu()
    }

    private func enableLaunchAtLogin() {
        let appPath = Bundle.main.bundlePath
        guard appPath.hasSuffix(".app") else {
            alert("请先把应用放到「应用程序」文件夹再开启开机自启。")
            return
        }

        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
                logLaunchAgent(appPath: appPath)
            }
        } else {
            logLaunchAgent(appPath: appPath)
        }
    }

    /// macOS 12 回退方案：直接写 LaunchAgent plist
    private func logLaunchAgent(appPath: String) {
        let label = "com.xiaofeixia.eyeguard"
        let dir = ("~/Library/LaunchAgents" as NSString).expandingTildeInPath
        let file = (dir as NSString).appendingPathComponent("\(label).plist")

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/open</string>
                <string>-a</string>
                <string>\(appPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """

        do {
            try FileManager.default.createDirectory(
                atPath: dir, withIntermediateDirectories: true, attributes: nil
            )
            try plist.write(toFile: file, atomically: true, encoding: .utf8)
        } catch {
            alert("写入开机启动项失败：\(error.localizedDescription)")
        }
    }

    private func disableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.unregister()
        }
        let path = ("~/Library/LaunchAgents/com.xiaofeixia.eyeguard.plist" as NSString).expandingTildeInPath
        try? FileManager.default.removeItem(atPath: path)
    }

    private func alert(_ text: String) {
        let a = NSAlert()
        a.messageText = "护眼强制休息"
        a.informativeText = text
        a.alertStyle = .informational
        a.runModal()
    }
}
