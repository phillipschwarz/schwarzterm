// Config/AppConfig.swift
import Foundation

struct AppConfig: Codable {
    var fontName: String = "Menlo"
    var fontSize: Double = 13.0
    var shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    var terminalBackground: CodableColor = CodableColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    var terminalForeground: CodableColor = CodableColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}
