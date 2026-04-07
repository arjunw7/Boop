import Foundation

class PermissionStore {
    private let configDir: URL
    private let configFile: URL

    /// Session IDs that have been granted "allow for this session"
    private var sessionAllowed: Set<String> = []
    private var config: Config
    var showAutoApproveToast: Bool = true

    struct Config: Codable {
        var mode: PermissionMode
        var notificationSound: String
        var preventSleep: Bool

        init() {
            mode = .default
            notificationSound = "Ping"
            preventSleep = true
        }
    }

    init(configDir: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".boop")) {
        self.configDir = configDir
        self.configFile = configDir.appendingPathComponent("config.json")
        self.config = Self.load(from: configDir.appendingPathComponent("config.json"))
    }

    var mode: PermissionMode { config.mode }
    var notificationSound: String { config.notificationSound }
    var preventSleep: Bool { config.preventSleep }

    func setNotificationSound(_ sound: String) throws {
        config.notificationSound = sound
        try save()
    }

    func setPreventSleep(_ enabled: Bool) throws {
        config.preventSleep = enabled
        try save()
    }

    func setMode(_ mode: PermissionMode) throws {
        config.mode = mode
        try save()
    }

    // MARK: - Session-scoped permissions

    func isSessionAllowed(_ sessionId: String) -> Bool {
        sessionAllowed.contains(sessionId)
    }

    func setSessionAllowed(_ sessionId: String) {
        sessionAllowed.insert(sessionId)
    }

    // MARK: - Auto-approve logic

    func shouldAutoApprove(category: ToolCategory, sessionId: String) -> Bool {
        // Permanent mode: allow everything
        if config.mode == .permanent { return true }
        // Smart Scope: auto-approve low-risk (file reads)
        if config.mode == .smartScope && category.riskLevel == .low { return true }
        // Session-scoped: allow if this session was granted access
        if isSessionAllowed(sessionId) { return true }
        return false
    }

    // MARK: - Persistence

    private static func load(from url: URL) -> Config {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            return Config()
        }
        return config
    }

    private func save() throws {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: configFile, options: .atomic)
    }
}
