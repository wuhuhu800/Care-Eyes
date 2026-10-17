import Cocoa

/// 应用入口。
///
/// 设计说明：使用 `@main` + `NSApplicationDelegate` 组合，
/// 避免依赖 main.swift 的顶层代码，从而支持 `-parse-as-library` 编译模式，
/// 也便于后续打包为 .app 时由 Info.plist 的 LSUIElement 控制 Dock 图标显隐。
@main
final class EyeGuardMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppController()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
