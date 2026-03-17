// Layout/PaneLayout.swift
import Foundation

/// A recursive layout tree.
/// A leaf names a pane type; a split contains two children.
indirect enum PaneLayout: Codable {
    case leaf(PaneType)
    case split(SplitLayout)

    enum PaneType: String, Codable {
        case terminal
        case fileManager
        case editor
    }

    struct SplitLayout: Codable {
        enum Axis: String, Codable { case horizontal, vertical }
        var axis: Axis
        /// 0…1, fraction of total size for the first child
        var position: Double
        var first: PaneLayout
        var second: PaneLayout
    }

    // MARK: Codable boilerplate
    private enum CodingKey: Swift.CodingKey { case type, leaf, split }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKey.self)
        switch self {
        case .leaf(let t):
            try c.encode("leaf", forKey: .type)
            try c.encode(t, forKey: .leaf)
        case .split(let s):
            try c.encode("split", forKey: .type)
            try c.encode(s, forKey: .split)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKey.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "leaf":  self = .leaf(try c.decode(PaneType.self, forKey: .leaf))
        case "split": self = .split(try c.decode(SplitLayout.self, forKey: .split))
        default: throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown type \(type)"))
        }
    }
}

extension PaneLayout {
    /// Default 3-pane layout:
    /// Left half:  FilePane (top 35%) + TerminalPane (bottom 65%)
    /// Right half: EditorPane (full)
    static var defaultLayout: PaneLayout {
        .split(.init(
            axis: .horizontal,
            position: 0.50,
            first: .split(.init(
                axis: .vertical,
                position: 0.40,
                first: .leaf(.fileManager),
                second: .leaf(.terminal)
            )),
            second: .leaf(.editor)
        ))
    }
}
