// Config/AppConfig.swift
import Foundation

struct AppConfig: Codable {
    var _note: String? = "Save this file and restart schwarzterm to apply changes."
    var fontName: String = "JetBrainsMono-Regular"
    var fontSize: Double = 13.0
    var shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    var themeName: String = "Midnight"
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}
