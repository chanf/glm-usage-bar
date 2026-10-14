import Foundation

struct Config: Codable {
    var apiKey: String
    var endpoint: String
    var refreshIntervalSeconds: Int

    static let defaultEndpoint = "https://open.bigmodel.cn"
    static let defaultInterval = 300

    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/glm-usage-bar", isDirectory: true)
    }

    static var fileURL: URL {
        directory.appendingPathComponent("config.json")
    }

    static func load() -> Config? {
        if let key = ProcessInfo.processInfo.environment["ZHIPU_API_KEY"], !key.isEmpty {
            return Config(apiKey: key, endpoint: defaultEndpoint, refreshIntervalSeconds: defaultInterval)
        }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Config.self, from: data)
    }

    func save() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Config.directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Config.fileURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Config.fileURL.path)
    }
}
