import AppKit
import ServiceManagement

final class StatusItemController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var config: Config? = Config.load()
    private var snapshot: QuotaSnapshot?
    private var lastError: String?
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private weak var keyField: NSTextField?

    private lazy var statusButton: NSStatusBarButton? = statusItem.button

    override init() {
        super.init()
        statusItem.menu = menu
        rebuildMenu()
        scheduleTimer()
        refresh()
    }

    // MARK: - Refresh

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = Double(config?.refreshIntervalSeconds ?? Config.defaultInterval)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func refresh() {
        guard let config else {
            lastError = "未配置 API Key"
            render()
            return
        }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            do {
                let snap = try await QuotaClient.fetch(config)
                guard !Task.isCancelled else { return }
                self?.snapshot = snap
                self?.lastError = nil
            } catch {
                guard !Task.isCancelled else { return }
                self?.lastError = error.localizedDescription
            }
            self?.render()
        }
    }

    // MARK: - Rendering

    private func render() {
        updateStatusTitle()
        rebuildMenu()
    }

    private func updateStatusTitle() {
        guard let button = statusButton else { return }

        let symbol: String
        let text: String
        if let snap = snapshot, let pct = snap.topPercentage {
            symbol = "gauge.with.needle"
            text = String(format: "%.0f%%", pct)
        } else if lastError != nil {
            symbol = "exclamationmark.triangle"
            text = "—"
        } else {
            symbol = "gauge.with.needle"
            text = "…"
        }

        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "GLM Coding Plan 用量")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.title = text
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        button.font = font
        button.toolTip = tooltipText()

        let titleWidth = (text as NSString).size(withAttributes: [.font: font]).width
        statusItem.length = ceil(titleWidth) + (image?.size.width ?? 0) + 16
    }

    private func tooltipText() -> String {
        guard let snap = snapshot else { return lastError ?? "GLM Coding Plan 用量" }
        var lines = ["GLM Coding Plan" + (snap.level.map { "（\($0)）" } ?? "")]
        for l in snap.limits {
            let p = l.percentage.map { String(format: "%.0f%%", $0) } ?? "-"
            lines.append("\(l.displayName)：\(p)")
        }
        return lines.joined(separator: "\n")
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        menu.autoenablesItems = false

        if let snap = snapshot {
            let header = item("\(snap.level.map { "套餐：\($0)" } ?? "GLM Coding Plan")")
            menu.addItem(header)
            menu.addItem(.separator())

            for limit in snap.limits {
                let pctStr = limit.percentage.map { String(format: "%.0f%%", $0) } ?? "-"
                let barStr = limit.percentage == nil ? "" : limit.barText
                let text = "\(limit.displayName)  \(pctStr)  \(barStr)".trimmingCharacters(in: .whitespaces)
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                ]
                let title = NSMutableAttributedString(string: text, attributes: attrs)
                if let p = limit.percentage, !barStr.isEmpty {
                    let range = (text as NSString).range(of: barStr)
                    if range.location != NSNotFound {
                        title.addAttribute(.foregroundColor, value: barColor(p), range: range)
                    }
                }
                let lineItem = NSMenuItem(title: "", action: #selector(noop), keyEquivalent: "")
                lineItem.attributedTitle = title
                lineItem.target = self
                lineItem.isEnabled = true
                menu.addItem(lineItem)
                if let remaining = limit.remaining {
                    menu.addItem(item("    剩余 \(fmt(remaining))", dim: true))
                }
                if let current = limit.currentValue, let total = limit.usage {
                    menu.addItem(item("    已用 \(fmt(current)) / \(fmt(total))", dim: true))
                }
                if let reset = limit.nextResetTime {
                    menu.addItem(item("    重置于 \(dateStr(reset))", dim: true))
                }
            }

            let details = snap.limits.flatMap { $0.usageDetails }
            if !details.isEmpty {
                menu.addItem(.separator())
                menu.addItem(item("模型消耗", dim: true))
                for d in details.sorted(by: { $0.usage > $1.usage }) {
                    menu.addItem(item("    \(d.model): \(fmt(d.usage))", dim: true))
                }
            }
        } else if let err = lastError {
            menu.addItem(item(err, color: .systemRed))
        } else {
            menu.addItem(item("加载中…", dim: true))
        }

        menu.addItem(.separator())
        if let snap = snapshot {
            menu.addItem(item("上次更新：\(timeStr(snap.fetchedAt))", dim: true))
        }
        menu.addItem(actionItem("立即刷新", #selector(refreshNow)))
        menu.addItem(actionItem(config == nil ? "设置 API Key…" : "更换 API Key…", #selector(editKey)))
        menu.addItem(actionItem(loginItemTitle(), #selector(toggleLogin)))
        menu.addItem(.separator())
        menu.addItem(actionItem("退出", #selector(quit)))
    }

    private func item(_ text: String, font: NSFont? = nil, color: NSColor? = nil, dim: Bool = false) -> NSMenuItem {
        let it = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color ?? NSColor.labelColor,
            .font: font ?? (dim ? NSFont.systemFont(ofSize: 12) : NSFont.systemFont(ofSize: 13))
        ]
        it.attributedTitle = NSAttributedString(string: text, attributes: attrs)
        it.target = self
        it.action = #selector(noop)
        it.isEnabled = true
        return it
    }

    @objc private func noop() {}

    private func barColor(_ percentage: Double) -> NSColor {
        if percentage >= 90 { return NSColor(red: 0.6, green: 0.0, blue: 0.0, alpha: 1) }
        if percentage >= 80 { return .systemRed }
        return .systemGreen
    }

    private func actionItem(_ text: String, _ sel: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: text, action: sel, keyEquivalent: "")
        it.target = self
        it.isEnabled = true
        return it
    }

    // MARK: - Actions

    @objc private func refreshNow() { refresh() }

    private func loginItemTitle() -> String {
        guard Bundle.main.bundleIdentifier != nil else { return "开机自动启动（需安装 .app）" }
        let enabled = SMAppService.mainApp.status == .enabled
        return enabled ? "开机自动启动  ✓" : "开机自动启动"
    }

    @objc private func toggleLogin() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                self.lastError = "自动启动设置失败：\(error.localizedDescription)"
            }
            self.render()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func editKey() {
        DispatchQueue.main.async { [weak self] in self?.showKeyAlert() }
    }

    @objc private func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        keyField?.stringValue = text.trimmingCharacters(in: .whitespacesAndNewlines)
        keyField?.window?.makeFirstResponder(keyField)
        if let editor = keyField?.currentEditor() { editor.selectAll(nil) }
    }

    private func showKeyAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "设置智谱 API Key"
        alert.informativeText = "在 open.bigmodel.cn 控制台创建 API Key。配置保存在 ~/.config/glm-usage-bar/config.json"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 330, height: 26))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 258, height: 26))
        field.placeholderString = "粘贴 API Key"
        field.stringValue = config?.apiKey ?? ""
        let pasteButton = NSButton(title: "粘贴", target: self, action: #selector(pasteFromClipboard))
        pasteButton.frame = NSRect(x: 264, y: 0, width: 66, height: 26)
        container.addSubview(field)
        container.addSubview(pasteButton)

        keyField = field
        alert.accessoryView = container
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        keyField = nil
        guard response == .alertFirstButtonReturn else { return }

        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        var newConfig = config ?? Config(apiKey: "", endpoint: Config.defaultEndpoint, refreshIntervalSeconds: Config.defaultInterval)
        newConfig.apiKey = key
        do {
            try newConfig.save()
            config = newConfig
            lastError = nil
            scheduleTimer()
            refresh()
        } catch {
            lastError = "保存失败：\(error.localizedDescription)"
            render()
        }
    }

    // MARK: - Formatting

    private func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = v < 100 ? 1 : 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func dateStr(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }

    private func timeStr(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }
}
