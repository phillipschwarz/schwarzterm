// Config/ConfigManager.swift
import Foundation

class ConfigManager {
    static let shared = ConfigManager()

    var config: AppConfig = AppConfig()

    var configURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("schwarzterm", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    private init() {
        load()
    }

    func load() {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            // Write default config so the user has a file to edit
            save()
            return
        }
        config = decoded
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: configURL)
    }

    /// Ensures a config file exists on disk, creating it with defaults if needed.
    func ensureConfigExists() {
        if !FileManager.default.fileExists(atPath: configURL.path) {
            save()
        }
    }
}
