import AppKit
import SwiftUI

@MainActor
enum AppTypography {
    static let regularName = "ArialMT"
    static let mediumName = "Arial-BoldMT"

    static func regular(_ size: CGFloat) -> Font {
        .custom(regularName, fixedSize: size)
    }

    static func medium(_ size: CGFloat) -> Font {
        .custom(mediumName, fixedSize: size)
    }

    static func latin(_ size: CGFloat, emphasized: Bool = false) -> Font {
        emphasized ? medium(size) : regular(size)
    }

    static func nativeFont(_ size: CGFloat, emphasized: Bool = false) -> NSFont {
        NSFont(name: emphasized ? mediumName : regularName, size: size)
            ?? .systemFont(ofSize: size)
    }

    static func text(_ value: String, size: CGFloat, emphasized: Bool = false) -> Text {
        Text(value).font(latin(size, emphasized: emphasized))
    }

    static func nativeText(_ value: String, size: CGFloat, emphasized: Bool = false) -> NSAttributedString {
        NSAttributedString(string: value, attributes: [.font: nativeFont(size, emphasized: emphasized)])
    }
}
