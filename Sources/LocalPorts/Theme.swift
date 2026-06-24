import SwiftUI

/// Visual constants for the app's slick dark look.
enum Theme {
    static let accent = Color(red: 0.20, green: 0.86, blue: 0.60)   // signal green
    static let accentDim = Color(red: 0.20, green: 0.86, blue: 0.60).opacity(0.16)

    static let bgTop = Color(red: 0.07, green: 0.09, blue: 0.14)
    static let bgBottom = Color(red: 0.04, green: 0.05, blue: 0.09)

    static let rowFill = Color.white.opacity(0.04)
    static let rowHover = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.07)

    static let background = LinearGradient(
        colors: [bgTop, bgBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A deterministic accent hue per process name, for the leading glyph chip.
    static func tint(for command: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.36, green: 0.72, blue: 1.00),   // blue
            Color(red: 0.66, green: 0.55, blue: 1.00),   // violet
            Color(red: 1.00, green: 0.62, blue: 0.40),   // orange
            Color(red: 0.20, green: 0.86, blue: 0.60),   // green
            Color(red: 1.00, green: 0.45, blue: 0.62),   // pink
            Color(red: 0.40, green: 0.84, blue: 0.86),   // teal
        ]
        let hash = command.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[hash % palette.count]
    }
}
