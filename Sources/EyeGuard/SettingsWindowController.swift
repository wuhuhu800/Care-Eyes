import Cocoa

/// 设置面板：调整工作间隔、休息时长、严格模式与紧急退出时长。
final class SettingsWindowController: NSWindowController {

    /// 设置保存后回调，用于重启计时
    var onSave: (() -> Void)?

    private let workField  = NSTextField()
    private let restField  = NSTextField()
    private let holdField  = NSTextField()
    private let strictCheck = NSButton(checkboxWithTitle: "严格模式（屏蔽 Cmd+Q / Cmd+W 等退出快捷键）", target: nil, action: nil)
    private let previewLabel = NSTextField(labelWithString: "")

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "护眼强制休息 · 设置"
        win.center()
        self.init(window: win)
        buildUI()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let workLabel = NSTextField(labelWithString: "工作时长（分钟）")
        let restLabel = NSTextField(labelWithString: "强制休息时长（分钟）")
        let holdLabel = NSTextField(labelWithString: "紧急退出长按（秒）")

        for f in [workField, restField, holdField] {
            f.alignment = .right
            f.translatesAutoresizingMaskIntoConstraints = false
        }
        for l in [workLabel, restLabel, holdLabel] {
            l.translatesAutoresizingMaskIntoConstraints = false
        }

        strictCheck.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.textColor = .secondaryLabelColor
        previewLabel.font = NSFont.systemFont(ofSize: 12)

        content.addSubview(workLabel); content.addSubview(workField)
        content.addSubview(restLabel); content.addSubview(restField)
        content.addSubview(holdLabel); content.addSubview(holdField)
        content.addSubview(strictCheck)
        content.addSubview(previewLabel)

        // 保存 / 取消按钮
        let saveBtn = NSButton(title: "保存", target: self, action: #selector(save))
        saveBtn.keyEquivalent = "\r"
        saveBtn.bezelStyle = .rounded
        saveBtn.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.bezelStyle = .rounded
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(saveBtn)
        content.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            workLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            workLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            workLabel.widthAnchor.constraint(equalToConstant: 190),

            workField.leadingAnchor.constraint(equalTo: workLabel.trailingAnchor, constant: 12),
            workField.centerYAnchor.constraint(equalTo: workLabel.centerYAnchor),
            workField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            restLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            restLabel.topAnchor.constraint(equalTo: workLabel.bottomAnchor, constant: 22),
            restLabel.widthAnchor.constraint(equalToConstant: 190),

            restField.leadingAnchor.constraint(equalTo: restLabel.trailingAnchor, constant: 12),
            restField.centerYAnchor.constraint(equalTo: restLabel.centerYAnchor),
            restField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            holdLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            holdLabel.topAnchor.constraint(equalTo: restLabel.bottomAnchor, constant: 22),
            holdLabel.widthAnchor.constraint(equalToConstant: 190),

            holdField.leadingAnchor.constraint(equalTo: holdLabel.trailingAnchor, constant: 12),
            holdField.centerYAnchor.constraint(equalTo: holdLabel.centerYAnchor),
            holdField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            strictCheck.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            strictCheck.topAnchor.constraint(equalTo: holdLabel.bottomAnchor, constant: 26),
            strictCheck.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),

            previewLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            previewLabel.topAnchor.constraint(equalTo: strictCheck.bottomAnchor, constant: 16),

            saveBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            saveBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            saveBtn.widthAnchor.constraint(equalToConstant: 88),

            cancelBtn.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -12),
            cancelBtn.centerYAnchor.constraint(equalTo: saveBtn.centerYAnchor),
            cancelBtn.widthAnchor.constraint(equalToConstant: 88)
        ])

        loadValues()
    }

    private func loadValues() {
        let c = Config.shared
        workField.stringValue = "\(c.workMinutes)"
        restField.stringValue = "\(c.restMinutes)"
        holdField.stringValue = "\(c.holdSeconds)"
        strictCheck.state = c.strictMode ? .on : .off
        refreshPreview()
    }

    private func refreshPreview() {
        let w = Int(workField.stringValue) ?? Config.shared.workMinutes
        let r = Int(restField.stringValue) ?? Config.shared.restMinutes
        let total = w + r
        let restsPerHour = Double(60) / Double(total)
        previewLabel.stringValue = String(
            format: "每个周期 %d 分钟（工作 %d + 休息 %d），每小时约休息 %.1f 次",
            total, w, r, restsPerHour
        )
    }

    @objc private func save() {
        let c = Config.shared
        c.workMinutes = Int(workField.stringValue) ?? c.workMinutes
        c.restMinutes = Int(restField.stringValue) ?? c.restMinutes
        c.holdSeconds = Int(holdField.stringValue) ?? c.holdSeconds
        c.strictMode = (strictCheck.state == .on)

        window?.close()
        onSave?()
    }

    @objc private func cancel() {
        window?.close()
        loadValues()
    }

    func showAndFocus() {
        loadValues()
        refreshPreview()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
