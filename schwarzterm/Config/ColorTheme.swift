// Config/ColorTheme.swift
import AppKit

struct ColorTheme: Codable {
    var name: String

    // --- App chrome ---
    var tabBarBackground:   CodableColor
    var tabSelectedFill:    CodableColor
    var tabSelectedBorder:  CodableColor
    var tabHoverFill:       CodableColor
    var tabCloseFill:       CodableColor
    var tabCloseGlyph:      CodableColor
    var tabActiveText:      CodableColor
    var tabInactiveText:    CodableColor
    var tabAddButton:       CodableColor

    // --- Editor ---
    var editorBackground:   CodableColor
    var editorForeground:   CodableColor
    var editorLineHighlight: CodableColor
    var welcomeBackground:  CodableColor
    var welcomeTitle:       CodableColor
    var welcomeSubtitle:    CodableColor

    // --- Find bar ---
    var findBarBackground:  CodableColor

    // --- File pane ---
    var filePaneBackground: CodableColor
    var filePaneToolbar:    CodableColor
    var filePaneDirectory:  CodableColor
    var filePaneFile:       CodableColor

    // --- Terminal ---
    var terminalBackground: CodableColor
    var terminalForeground: CodableColor

    // --- Syntax ---
    var syntaxKeyword:      CodableColor
    var syntaxString:       CodableColor
    var syntaxComment:      CodableColor
    var syntaxNumber:       CodableColor
    var syntaxTypeName:     CodableColor
    var syntaxAttribute:    CodableColor
    var syntaxOperator:     CodableColor
    var syntaxPunctuation:  CodableColor
}

// MARK: - CodableColor → NSColor

extension CodableColor {
    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Built-in Themes

extension ColorTheme {

    // MARK: Midnight (default — formalizes the current hardcoded palette)

    static let midnight = ColorTheme(
        name: "Midnight",
        tabBarBackground:   .init(r: 0.11, g: 0.11, b: 0.11),
        tabSelectedFill:    .init(r: 1.00, g: 1.00, b: 1.00),
        tabSelectedBorder:  .init(r: 1.00, g: 1.00, b: 1.00),
        tabHoverFill:       .init(r: 1.00, g: 1.00, b: 1.00),
        tabCloseFill:       .init(r: 1.00, g: 1.00, b: 1.00),
        tabCloseGlyph:      .init(r: 0.65, g: 0.65, b: 0.65),
        tabActiveText:      .init(r: 0.95, g: 0.95, b: 0.95),
        tabInactiveText:    .init(r: 0.55, g: 0.55, b: 0.55),
        tabAddButton:       .init(r: 0.55, g: 0.55, b: 0.55),
        editorBackground:   .init(r: 0.11, g: 0.11, b: 0.11),
        editorForeground:   .init(r: 0.90, g: 0.90, b: 0.90),
        editorLineHighlight: .init(r: 1.00, g: 1.00, b: 1.00),
        welcomeBackground:  .init(r: 0.11, g: 0.11, b: 0.11),
        welcomeTitle:       .init(r: 0.35, g: 0.35, b: 0.35),
        welcomeSubtitle:    .init(r: 0.28, g: 0.28, b: 0.28),
        findBarBackground:  .init(r: 0.11, g: 0.11, b: 0.11),
        filePaneBackground: .init(r: 0.11, g: 0.11, b: 0.11),
        filePaneToolbar:    .init(r: 0.11, g: 0.11, b: 0.11),
        filePaneDirectory:  .init(r: 0.90, g: 0.90, b: 0.90),
        filePaneFile:       .init(r: 0.55, g: 0.55, b: 0.55),
        terminalBackground: .init(r: 0.12, g: 0.12, b: 0.12),
        terminalForeground: .init(r: 0.90, g: 0.90, b: 0.90),
        syntaxKeyword:      .init(r: 0.56, g: 0.70, b: 1.00),
        syntaxString:       .init(r: 0.80, g: 0.55, b: 0.40),
        syntaxComment:      .init(r: 0.45, g: 0.45, b: 0.45),
        syntaxNumber:       .init(r: 0.70, g: 0.90, b: 0.65),
        syntaxTypeName:     .init(r: 0.85, g: 0.75, b: 0.45),
        syntaxAttribute:    .init(r: 0.70, g: 0.85, b: 0.60),
        syntaxOperator:     .init(r: 0.75, g: 0.75, b: 0.75),
        syntaxPunctuation:  .init(r: 0.60, g: 0.60, b: 0.60)
    )

    // MARK: Catppuccin Mocha

    static let catppuccinMocha = ColorTheme(
        name: "Catppuccin Mocha",
        tabBarBackground:   .init(r: 0.094, g: 0.094, b: 0.145),
        tabSelectedFill:    .init(r: 0.804, g: 0.839, b: 0.957),
        tabSelectedBorder:  .init(r: 0.804, g: 0.839, b: 0.957),
        tabHoverFill:       .init(r: 0.804, g: 0.839, b: 0.957),
        tabCloseFill:       .init(r: 0.804, g: 0.839, b: 0.957),
        tabCloseGlyph:      .init(r: 0.498, g: 0.518, b: 0.612),
        tabActiveText:      .init(r: 0.804, g: 0.839, b: 0.957),
        tabInactiveText:    .init(r: 0.498, g: 0.518, b: 0.612),
        tabAddButton:       .init(r: 0.576, g: 0.600, b: 0.698),
        editorBackground:   .init(r: 0.118, g: 0.118, b: 0.180),
        editorForeground:   .init(r: 0.804, g: 0.839, b: 0.957),
        editorLineHighlight: .init(r: 0.192, g: 0.196, b: 0.267),
        welcomeBackground:  .init(r: 0.118, g: 0.118, b: 0.180),
        welcomeTitle:       .init(r: 0.345, g: 0.357, b: 0.439),
        welcomeSubtitle:    .init(r: 0.271, g: 0.278, b: 0.353),
        findBarBackground:  .init(r: 0.094, g: 0.094, b: 0.145),
        filePaneBackground: .init(r: 0.118, g: 0.118, b: 0.180),
        filePaneToolbar:    .init(r: 0.094, g: 0.094, b: 0.145),
        filePaneDirectory:  .init(r: 0.804, g: 0.839, b: 0.957),
        filePaneFile:       .init(r: 0.651, g: 0.678, b: 0.784),
        terminalBackground: .init(r: 0.067, g: 0.067, b: 0.106),
        terminalForeground: .init(r: 0.804, g: 0.839, b: 0.957),
        syntaxKeyword:      .init(r: 0.796, g: 0.651, b: 0.969),
        syntaxString:       .init(r: 0.651, g: 0.890, b: 0.631),
        syntaxComment:      .init(r: 0.498, g: 0.518, b: 0.612),
        syntaxNumber:       .init(r: 0.980, g: 0.702, b: 0.529),
        syntaxTypeName:     .init(r: 0.976, g: 0.886, b: 0.686),
        syntaxAttribute:    .init(r: 0.580, g: 0.886, b: 0.835),
        syntaxOperator:     .init(r: 0.537, g: 0.706, b: 0.980),
        syntaxPunctuation:  .init(r: 0.576, g: 0.600, b: 0.698)
    )

    // MARK: Catppuccin Latte

    static let catppuccinLatte = ColorTheme(
        name: "Catppuccin Latte",
        tabBarBackground:   .init(r: 0.902, g: 0.914, b: 0.937),
        tabSelectedFill:    .init(r: 0.298, g: 0.310, b: 0.412),
        tabSelectedBorder:  .init(r: 0.298, g: 0.310, b: 0.412),
        tabHoverFill:       .init(r: 0.298, g: 0.310, b: 0.412),
        tabCloseFill:       .init(r: 0.298, g: 0.310, b: 0.412),
        tabCloseGlyph:      .init(r: 0.549, g: 0.561, b: 0.631),
        tabActiveText:      .init(r: 0.298, g: 0.310, b: 0.412),
        tabInactiveText:    .init(r: 0.549, g: 0.561, b: 0.631),
        tabAddButton:       .init(r: 0.424, g: 0.435, b: 0.522),
        editorBackground:   .init(r: 0.937, g: 0.945, b: 0.961),
        editorForeground:   .init(r: 0.298, g: 0.310, b: 0.412),
        editorLineHighlight: .init(r: 0.800, g: 0.816, b: 0.855),
        welcomeBackground:  .init(r: 0.937, g: 0.945, b: 0.961),
        welcomeTitle:       .init(r: 0.737, g: 0.753, b: 0.800),
        welcomeSubtitle:    .init(r: 0.800, g: 0.816, b: 0.855),
        findBarBackground:  .init(r: 0.902, g: 0.914, b: 0.937),
        filePaneBackground: .init(r: 0.937, g: 0.945, b: 0.961),
        filePaneToolbar:    .init(r: 0.902, g: 0.914, b: 0.937),
        filePaneDirectory:  .init(r: 0.298, g: 0.310, b: 0.412),
        filePaneFile:       .init(r: 0.424, g: 0.435, b: 0.522),
        terminalBackground: .init(r: 0.863, g: 0.878, b: 0.910),
        terminalForeground: .init(r: 0.298, g: 0.310, b: 0.412),
        syntaxKeyword:      .init(r: 0.533, g: 0.224, b: 0.937),
        syntaxString:       .init(r: 0.251, g: 0.627, b: 0.169),
        syntaxComment:      .init(r: 0.549, g: 0.561, b: 0.631),
        syntaxNumber:       .init(r: 0.996, g: 0.392, b: 0.043),
        syntaxTypeName:     .init(r: 0.875, g: 0.557, b: 0.114),
        syntaxAttribute:    .init(r: 0.090, g: 0.573, b: 0.600),
        syntaxOperator:     .init(r: 0.118, g: 0.400, b: 0.961),
        syntaxPunctuation:  .init(r: 0.424, g: 0.435, b: 0.522)
    )

    // MARK: Dracula

    static let dracula = ColorTheme(
        name: "Dracula",
        tabBarBackground:   .init(r: 0.129, g: 0.133, b: 0.173),
        tabSelectedFill:    .init(r: 0.973, g: 0.973, b: 0.949),
        tabSelectedBorder:  .init(r: 0.973, g: 0.973, b: 0.949),
        tabHoverFill:       .init(r: 0.973, g: 0.973, b: 0.949),
        tabCloseFill:       .init(r: 0.973, g: 0.973, b: 0.949),
        tabCloseGlyph:      .init(r: 0.384, g: 0.447, b: 0.643),
        tabActiveText:      .init(r: 0.973, g: 0.973, b: 0.949),
        tabInactiveText:    .init(r: 0.384, g: 0.447, b: 0.643),
        tabAddButton:       .init(r: 0.384, g: 0.447, b: 0.643),
        editorBackground:   .init(r: 0.157, g: 0.165, b: 0.212),
        editorForeground:   .init(r: 0.973, g: 0.973, b: 0.949),
        editorLineHighlight: .init(r: 0.267, g: 0.278, b: 0.353),
        welcomeBackground:  .init(r: 0.157, g: 0.165, b: 0.212),
        welcomeTitle:       .init(r: 0.267, g: 0.278, b: 0.353),
        welcomeSubtitle:    .init(r: 0.267, g: 0.278, b: 0.353),
        findBarBackground:  .init(r: 0.129, g: 0.133, b: 0.173),
        filePaneBackground: .init(r: 0.157, g: 0.165, b: 0.212),
        filePaneToolbar:    .init(r: 0.129, g: 0.133, b: 0.173),
        filePaneDirectory:  .init(r: 0.973, g: 0.973, b: 0.949),
        filePaneFile:       .init(r: 0.384, g: 0.447, b: 0.643),
        terminalBackground: .init(r: 0.157, g: 0.165, b: 0.212),
        terminalForeground: .init(r: 0.973, g: 0.973, b: 0.949),
        syntaxKeyword:      .init(r: 1.000, g: 0.475, b: 0.776),
        syntaxString:       .init(r: 0.945, g: 0.980, b: 0.549),
        syntaxComment:      .init(r: 0.384, g: 0.447, b: 0.643),
        syntaxNumber:       .init(r: 0.741, g: 0.576, b: 0.976),
        syntaxTypeName:     .init(r: 0.545, g: 0.914, b: 0.992),
        syntaxAttribute:    .init(r: 0.314, g: 0.980, b: 0.482),
        syntaxOperator:     .init(r: 1.000, g: 0.475, b: 0.776),
        syntaxPunctuation:  .init(r: 0.973, g: 0.973, b: 0.949)
    )

    // MARK: Nord

    static let nord = ColorTheme(
        name: "Nord",
        tabBarBackground:   .init(r: 0.231, g: 0.259, b: 0.322),
        tabSelectedFill:    .init(r: 0.925, g: 0.937, b: 0.957),
        tabSelectedBorder:  .init(r: 0.925, g: 0.937, b: 0.957),
        tabHoverFill:       .init(r: 0.925, g: 0.937, b: 0.957),
        tabCloseFill:       .init(r: 0.925, g: 0.937, b: 0.957),
        tabCloseGlyph:      .init(r: 0.298, g: 0.337, b: 0.416),
        tabActiveText:      .init(r: 0.925, g: 0.937, b: 0.957),
        tabInactiveText:    .init(r: 0.298, g: 0.337, b: 0.416),
        tabAddButton:       .init(r: 0.298, g: 0.337, b: 0.416),
        editorBackground:   .init(r: 0.180, g: 0.204, b: 0.251),
        editorForeground:   .init(r: 0.847, g: 0.871, b: 0.914),
        editorLineHighlight: .init(r: 0.231, g: 0.259, b: 0.322),
        welcomeBackground:  .init(r: 0.180, g: 0.204, b: 0.251),
        welcomeTitle:       .init(r: 0.263, g: 0.298, b: 0.369),
        welcomeSubtitle:    .init(r: 0.231, g: 0.259, b: 0.322),
        findBarBackground:  .init(r: 0.231, g: 0.259, b: 0.322),
        filePaneBackground: .init(r: 0.180, g: 0.204, b: 0.251),
        filePaneToolbar:    .init(r: 0.231, g: 0.259, b: 0.322),
        filePaneDirectory:  .init(r: 0.925, g: 0.937, b: 0.957),
        filePaneFile:       .init(r: 0.298, g: 0.337, b: 0.416),
        terminalBackground: .init(r: 0.180, g: 0.204, b: 0.251),
        terminalForeground: .init(r: 0.847, g: 0.871, b: 0.914),
        syntaxKeyword:      .init(r: 0.506, g: 0.631, b: 0.757),
        syntaxString:       .init(r: 0.639, g: 0.745, b: 0.549),
        syntaxComment:      .init(r: 0.298, g: 0.337, b: 0.416),
        syntaxNumber:       .init(r: 0.706, g: 0.557, b: 0.678),
        syntaxTypeName:     .init(r: 0.561, g: 0.737, b: 0.733),
        syntaxAttribute:    .init(r: 0.533, g: 0.753, b: 0.816),
        syntaxOperator:     .init(r: 0.506, g: 0.631, b: 0.757),
        syntaxPunctuation:  .init(r: 0.298, g: 0.337, b: 0.416)
    )

    /// All built-in themes.
    static let allBuiltIn: [ColorTheme] = [.midnight, .catppuccinMocha, .catppuccinLatte, .dracula, .nord]
}
