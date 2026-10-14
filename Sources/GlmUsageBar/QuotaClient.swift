import Foundation

struct QuotaLimit {
    var type: String
    var usage: Double?
    var remaining: Double?
    var percentage: Double?
    var currentValue: Double?
    var nextResetTime: Date?
    var usageDetails: [(model: String, usage: Double)]

    var displayName: String {
        let t = type.uppercased()
        if t.contains("WEEK") { return "每周额度" }
        if t.contains("TIME") { return "MCP 月度额度" }
        if t.contains("REQUEST") { return "请求数额度" }
        if t.contains("TOKEN") { return "5 小时 Token 池" }
        return type
    }

    var barText: String {
        guard let p = percentage else { return "" }
        let width = 20
        let filled = min(width, max(0, Int((p / 100 * Double(width)).rounded(.down))))
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }
}

struct QuotaSnapshot {
    var level: String?
    var limits: [QuotaLimit]
    var fetchedAt: Date

    var topPercentage: Double? {
        let fiveHour = limits.first {
            let t = $0.type.uppercased()
            return t.contains("TOKEN") && !t.contains("WEEK")
        }
        return fiveHour?.percentage ?? limits.compactMap { $0.percentage }.max()
    }
}

enum QuotaError: LocalizedError {
    case missingKey
    case http(Int, String)
    case badPayload
    case badPayloadMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "尚未配置 API Key"
        case .http(let code, let body): return "HTTP \(code): \(body.prefix(200))"
        case .badPayload: return "响应格式无法解析"
        case .badPayloadMessage(let msg): return msg
        }
    }
}

enum QuotaClient {
    static func fetch(_ config: Config) async throws -> QuotaSnapshot {
        guard !config.apiKey.isEmpty else { throw QuotaError.missingKey }
        let url = URL(string: config.endpoint + "/api/monitor/usage/quota/limit")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(config.apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw QuotaError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaError.badPayload
        }
        if let success = root["success"] as? Bool, !success {
            let msg = (root["msg"] as? String) ?? "接口返回失败"
            let code = (root["code"] as? Int).map { " (code \($0))" } ?? ""
            throw QuotaError.badPayloadMessage("\(msg)\(code)")
        }
        let payload = (root["data"] as? [String: Any]) ?? root
        return parse(payload)
    }

    private static func parse(_ payload: [String: Any]) -> QuotaSnapshot {
        let level = payload["level"] as? String
        let rawLimits = payload["limits"] as? [[String: Any]] ?? []
        let limits = rawLimits.map { item -> QuotaLimit in
            var details: [(String, Double)] = []
            if let arr = item["usageDetails"] as? [[String: Any]] {
                for d in arr {
                    let model = (d["modelCode"] as? String) ?? (d["model"] as? String) ?? "?"
                    let usage = number(d["usage"]) ?? 0
                    details.append((model, usage))
                }
            }
            let usage = number(item["usage"])
            let remaining = number(item["remaining"])
            var percentage = number(item["percentage"])
            if let u = usage, let r = remaining, u + r > 0 {
                percentage = (u / (u + r)) * 100
            }
            if let p = percentage { percentage = min(100, max(0, p)) }
            return QuotaLimit(
                type: item["type"] as? String ?? "?",
                usage: usage,
                remaining: remaining,
                percentage: percentage,
                currentValue: number(item["currentValue"]),
                nextResetTime: number(item["nextResetTime"]).map { Date(timeIntervalSince1970: $0 / 1000) },
                usageDetails: details
            )
        }
        return QuotaSnapshot(level: level, limits: limits, fetchedAt: Date())
    }

    private static func number(_ any: Any?) -> Double? {
        switch any {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let s as String: return Double(s)
        default: return nil
        }
    }
}
