import AppKit

struct TerminalColorScheme {
    let background: NSColor
    let foreground: NSColor
    let cursor: NSColor
    let selection: NSColor
    let ansiColors: [NSColor]
    let ansiBrightColors: [NSColor]

    static let dark = TerminalColorScheme(
        background: NSColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0),
        foreground: NSColor(red: 0.83, green: 0.84, blue: 0.85, alpha: 1.0),
        cursor: NSColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0),
        selection: NSColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 0.5),
        ansiColors: [
            NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),      // Black
            NSColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0),      // Red
            NSColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0),      // Green
            NSColor(red: 0.8, green: 0.8, blue: 0.0, alpha: 1.0),      // Yellow
            NSColor(red: 0.0, green: 0.0, blue: 0.8, alpha: 1.0),      // Blue
            NSColor(red: 0.8, green: 0.0, blue: 0.8, alpha: 1.0),      // Magenta
            NSColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0),      // Cyan
            NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)       // White
        ],
        ansiBrightColors: [
            NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),      // Bright Black
            NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0),      // Bright Red
            NSColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0),      // Bright Green
            NSColor(red: 1.0, green: 1.0, blue: 0.3, alpha: 1.0),      // Bright Yellow
            NSColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0),      // Bright Blue
            NSColor(red: 1.0, green: 0.3, blue: 1.0, alpha: 1.0),      // Bright Magenta
            NSColor(red: 0.3, green: 1.0, blue: 1.0, alpha: 1.0),      // Bright Cyan
            NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)       // Bright White
        ]
    )

    static let light = TerminalColorScheme(
        background: NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
        foreground: NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
        cursor: NSColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1.0),
        selection: NSColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 0.5),
        ansiColors: [
            NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.7, green: 0.0, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.6, green: 0.6, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.0, green: 0.0, blue: 0.7, alpha: 1.0),
            NSColor(red: 0.7, green: 0.0, blue: 0.7, alpha: 1.0),
            NSColor(red: 0.0, green: 0.6, blue: 0.6, alpha: 1.0),
            NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        ],
        ansiBrightColors: [
            NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
            NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0),
            NSColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1.0),
            NSColor(red: 0.9, green: 0.9, blue: 0.2, alpha: 1.0),
            NSColor(red: 0.3, green: 0.3, blue: 0.9, alpha: 1.0),
            NSColor(red: 0.9, green: 0.2, blue: 0.9, alpha: 1.0),
            NSColor(red: 0.2, green: 0.9, blue: 0.9, alpha: 1.0),
            NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        ]
    )

    static let solarizedDark = TerminalColorScheme(
        background: NSColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1.0),
        foreground: NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
        cursor: NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
        selection: NSColor(red: 0.07, green: 0.22, blue: 0.26, alpha: 1.0),
        ansiColors: [
            NSColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0),
            NSColor(red: 0.86, green: 0.20, blue: 0.18, alpha: 1.0),
            NSColor(red: 0.52, green: 0.60, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.71, green: 0.54, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
            NSColor(red: 0.83, green: 0.21, blue: 0.51, alpha: 1.0),
            NSColor(red: 0.16, green: 0.63, blue: 0.60, alpha: 1.0),
            NSColor(red: 0.93, green: 0.91, blue: 0.84, alpha: 1.0)
        ],
        ansiBrightColors: [
            NSColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1.0),
            NSColor(red: 0.80, green: 0.29, blue: 0.09, alpha: 1.0),
            NSColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0),
            NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1.0),
            NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
            NSColor(red: 0.42, green: 0.44, blue: 0.77, alpha: 1.0),
            NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1.0),
            NSColor(red: 0.99, green: 0.96, blue: 0.89, alpha: 1.0)
        ]
    )

    func get256Color(_ index: Int) -> NSColor {
        // Standard colors (0-15)
        if index < 8 {
            return ansiColors[index]
        } else if index < 16 {
            return ansiBrightColors[index - 8]
        }

        // 216 color cube (16-231)
        if index >= 16 && index < 232 {
            let idx = index - 16
            let r = (idx / 36) % 6
            let g = (idx / 6) % 6
            let b = idx % 6

            let redValue = CGFloat(r) / 5.0
            let greenValue = CGFloat(g) / 5.0
            let blueValue = CGFloat(b) / 5.0

            return NSColor(red: redValue, green: greenValue, blue: blueValue, alpha: 1.0)
        }

        // Grayscale (232-255)
        if index >= 232 {
            let gray = CGFloat(index - 232) / 23.0
            return NSColor(red: gray, green: gray, blue: gray, alpha: 1.0)
        }

        return foreground
    }
}

// Syntax highlighting colors for better code visibility
extension TerminalColorScheme {
    static let syntaxHighlightColors = [
        "keyword": NSColor(red: 0.8, green: 0.47, blue: 0.86, alpha: 1.0),
        "string": NSColor(red: 0.65, green: 0.89, blue: 0.18, alpha: 1.0),
        "number": NSColor(red: 1.0, green: 0.75, blue: 0.4, alpha: 1.0),
        "comment": NSColor(red: 0.45, green: 0.51, blue: 0.55, alpha: 1.0),
        "function": NSColor(red: 0.33, green: 0.68, blue: 0.95, alpha: 1.0),
        "error": NSColor(red: 0.98, green: 0.35, blue: 0.35, alpha: 1.0),
        "warning": NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),
        "success": NSColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0)
    ]
}
