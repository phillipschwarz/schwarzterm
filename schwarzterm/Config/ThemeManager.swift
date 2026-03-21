// Config/ThemeManager.swift
import AppKit

final class ThemeManager {
    static let shared = ThemeManager()

    private(set) var current: ColorTheme = .midnight {
        didSet {
            NotificationCenter.default.post(name: .themeChanged, object: nil)
            ConfigManager.shared.config.themeName = current.name
            ConfigManager.shared.save()
        }
    }

    private init() {}

    func apply(_ theme: ColorTheme) {
        current = theme
    }

    func apply(named name: String) {
        if let match = ColorTheme.allBuiltIn.first(where: { $0.name == name }) {
            apply(match)
        }
    }
}
