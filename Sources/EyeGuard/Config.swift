import Foundation

/// 配置模型：所有可调参数集中在此，统一读写 UserDefaults。
final class Config {

    static let shared = Config()
    private let store = UserDefaults.standard

    private enum Key {
        static let workMinutes   = "workMinutes"
        static let restMinutes   = "restMinutes"
        static let enabled       = "enabled"
        static let holdSeconds   = "holdSeconds"
        static let strictMode    = "strictMode"
    }

    private init() {
        store.register(defaults: [
            Key.workMinutes: 60,
            Key.restMinutes: 10,
            Key.enabled: true,
            Key.holdSeconds: 5,
            Key.strictMode: true
        ])
    }

    /// 工作时长（分钟），即两次休息之间的间隔
    var workMinutes: Int {
        get { max(1, store.integer(forKey: Key.workMinutes)) }
        set { store.set(max(1, newValue), forKey: Key.workMinutes) }
    }

    /// 强制休息时长（分钟）
    var restMinutes: Int {
        get { max(1, store.integer(forKey: Key.restMinutes)) }
        set { store.set(max(1, newValue), forKey: Key.restMinutes) }
    }

    /// 是否启用计时
    var enabled: Bool {
        get { store.bool(forKey: Key.enabled) }
        set { store.set(newValue, forKey: Key.enabled) }
    }

    /// 紧急退出需长按的秒数
    var holdSeconds: Int {
        get { max(1, store.integer(forKey: Key.holdSeconds)) }
        set { store.set(max(1, newValue), forKey: Key.holdSeconds) }
    }

    /// 严格模式：禁止 Cmd+Q / Cmd+W 等常规退出手段
    var strictMode: Bool {
        get { store.bool(forKey: Key.strictMode) }
        set { store.set(newValue, forKey: Key.strictMode) }
    }

    var workSeconds: TimeInterval { TimeInterval(workMinutes * 60) }
    var restSeconds: TimeInterval { TimeInterval(restMinutes * 60) }

    var summary: String {
        "工作 \(workMinutes) 分钟 / 休息 \(restMinutes) 分钟"
    }
}
