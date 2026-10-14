import AppKit

func printSnapshot() {
    guard let config = Config.load() else {
        FileHandle.standardError.write("未配置 API Key。请设置环境变量 ZHIPU_API_KEY，或先运行一次应用通过菜单“设置 API Key…”保存。\n".data(using: .utf8)!)
        exit(1)
    }
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<QuotaSnapshot, Error>?
    Task.detached {
        do {
            result = .success(try await QuotaClient.fetch(config))
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()

    switch result! {
    case .success(let snap):
        print(snap.level.map { "套餐：\($0)" } ?? "GLM Coding Plan")
        for l in snap.limits {
            print("\n[\(l.displayName)] \(l.type)")
            if let p = l.percentage { print(String(format: "  进度 %.0f%%  %@", p, l.barText)) }
            if let u = l.usage { print("  usage: \(Int(u))") }
            if let r = l.remaining { print("  remaining: \(Int(r))") }
            if let c = l.currentValue { print("  current: \(Int(c))") }
            for d in l.usageDetails { print("    \(d.model): \(Int(d.usage))") }
            if let t = l.nextResetTime {
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"
                print("  next reset: \(f.string(from: t))")
            }
        }
    case .failure(let err):
        FileHandle.standardError.write("查询失败：\(err.localizedDescription)\n".data(using: .utf8)!)
        exit(1)
    }
}

if CommandLine.arguments.contains("--print") {
    printSnapshot()
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = StatusItemController()
app.delegate = controller
app.run()
