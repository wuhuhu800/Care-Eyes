import Cocoa

/// 全屏休息遮罩窗口。
///
/// 设计要点：
/// - 每个显示器一个窗口，合并成一个「集合」，避免多屏时只遮主屏；
/// - `.screenSaver` 窗口层级（高于普通窗口、菜单栏、Dock）；
/// - 不进入系统全屏空间（避免触发动画与切屏），而是直接覆盖当前空间；
/// - 允许加入所有空间并置顶，减少用户切空间绕过遮罩的可能。
final class RestWindow: NSWindow {

    /// 该窗口绑定的屏幕，用于计算覆盖范围
    let targetScreen: NSScreen

    init(screen: NSScreen) {
        self.targetScreen = screen
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // 置顶到屏保级别：高于菜单栏、Dock 与普通应用窗口
        self.level = .screenSaver
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.backgroundColor = NSColor.black
        self.isOpaque = true
        self.hasShadow = false
        self.isMovable = false
        self.isReleasedWhenClosed = false
        self.ignoresMouseEvents = false
        self.animationBehavior = .none

        // 不显示任何窗口按钮
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        self.contentView = RestView(frame: screen.frame, screen: screen)
    }

    /// 遮罩期间禁用常规退出快捷键（严格模式）
    override func keyDown(with event: NSEvent) {
        // 有意吞掉所有按键，交给 RestView 处理长按逻辑
        super.keyDown(with: event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
