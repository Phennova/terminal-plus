import Foundation
import AppKit
import SwiftUI

struct TerminalCell {
    var character: Character
    var foregroundColor: NSColor?
    var backgroundColor: NSColor?
    var bold: Bool = false
    var italic: Bool = false
    var underline: Bool = false
}

class TerminalEmulator: ObservableObject {
    @Published var buffer: [[TerminalCell]] = []
    @Published var cursorX: Int = 0
    @Published var cursorY: Int = 0
    @Published var cursorVisible: Bool = true
    @Published var colorScheme: TerminalColorScheme = .dark

    private var rows: Int = 24
    private var cols: Int = 80
    private var scrollbackBuffer: [[TerminalCell]] = []
    private var maxScrollback: Int = 10000

    // Current text attributes
    private var currentForeground: NSColor?
    private var currentBackground: NSColor?
    private var currentBold: Bool = false
    private var currentItalic: Bool = false
    private var currentUnderline: Bool = false

    // Parser state
    private var escapeBuffer: String = ""
    private var inEscapeSequence: Bool = false

    // Update batching
    private var updateTimer: Timer?
    private var needsRedraw: Bool = false

    var onInput: ((String) -> Void)?

    init() {
        initializeBuffer()
        setupUpdateTimer()
    }

    private func setupUpdateTimer() {
        // Batch updates to reduce frequency
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self, self.needsRedraw else { return }
            self.needsRedraw = false
            // Trigger view update on main thread asynchronously
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    private func initializeBuffer() {
        buffer = Array(repeating: Array(repeating: TerminalCell(character: " "), count: cols), count: rows)
    }

    func resize(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        DispatchQueue.main.async { [weak self] in
            self?.initializeBuffer()
        }
    }

    func processOutput(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }

        // Process data on background queue
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }

            for char in string {
                if self.inEscapeSequence {
                    self.escapeBuffer.append(char)
                    if self.processEscapeSequence() {
                        self.inEscapeSequence = false
                        self.escapeBuffer = ""
                    }
                } else if char == "\u{1B}" { // ESC character
                    self.inEscapeSequence = true
                    self.escapeBuffer = "\u{1B}"
                } else {
                    self.processCharacter(char)
                }
            }

            // Mark that we need a redraw (timer will handle the actual update)
            self.needsRedraw = true
        }
    }

    private func processCharacter(_ char: Character) {
        switch char {
        case "\n":
            cursorY += 1
            if cursorY >= rows {
                scrollUp()
                cursorY = rows - 1
            }
        case "\r":
            cursorX = 0
        case "\u{08}": // Backspace
            if cursorX > 0 {
                cursorX -= 1
            }
        case "\t":
            cursorX = ((cursorX / 8) + 1) * 8
            if cursorX >= cols {
                cursorX = cols - 1
            }
        default:
            if cursorX >= cols {
                cursorX = 0
                cursorY += 1
                if cursorY >= rows {
                    scrollUp()
                    cursorY = rows - 1
                }
            }

            if cursorY < buffer.count && cursorX < buffer[cursorY].count {
                buffer[cursorY][cursorX] = TerminalCell(
                    character: char,
                    foregroundColor: currentForeground,
                    backgroundColor: currentBackground,
                    bold: currentBold,
                    italic: currentItalic,
                    underline: currentUnderline
                )
            }
            cursorX += 1
        }
    }

    private func processEscapeSequence() -> Bool {
        // CSI (Control Sequence Introducer) sequences
        if escapeBuffer.hasPrefix("\u{1B}[") {
            let sequence = String(escapeBuffer.dropFirst(2))

            // Check if sequence is complete
            let terminalChars = CharacterSet(charactersIn: "ABCDEFGHJKSTfhlmnsu")
            if let lastChar = sequence.last,
               terminalChars.contains(lastChar.unicodeScalars.first!) {
                handleCSISequence(sequence)
                return true
            }
            return false
        }

        // OSC (Operating System Command) sequences
        if escapeBuffer.hasPrefix("\u{1B}]") {
            if escapeBuffer.contains("\u{07}") || escapeBuffer.hasSuffix("\u{1B}\\") {
                return true // OSC sequence complete
            }
            return false
        }

        return true // Unknown sequence, terminate
    }

    private func handleCSISequence(_ sequence: String) {
        let command = sequence.last!
        let parameters = String(sequence.dropLast())
            .split(separator: ";")
            .compactMap { Int($0) }

        switch command {
        case "m": // SGR (Select Graphic Rendition)
            handleSGR(parameters.isEmpty ? [0] : parameters)

        case "H", "f": // Cursor Position
            let row = parameters.first ?? 1
            let col = parameters.count > 1 ? parameters[1] : 1
            cursorY = min(max(row - 1, 0), rows - 1)
            cursorX = min(max(col - 1, 0), cols - 1)

        case "A": // Cursor Up
            let count = parameters.first ?? 1
            cursorY = max(cursorY - count, 0)

        case "B": // Cursor Down
            let count = parameters.first ?? 1
            cursorY = min(cursorY + count, rows - 1)

        case "C": // Cursor Forward
            let count = parameters.first ?? 1
            cursorX = min(cursorX + count, cols - 1)

        case "D": // Cursor Backward
            let count = parameters.first ?? 1
            cursorX = max(cursorX - count, 0)

        case "J": // Erase in Display
            let mode = parameters.first ?? 0
            eraseDisplay(mode: mode)

        case "K": // Erase in Line
            let mode = parameters.first ?? 0
            eraseLine(mode: mode)

        case "h": // Set Mode
            break

        case "l": // Reset Mode
            break

        default:
            break
        }
    }

    private func handleSGR(_ params: [Int]) {
        var i = 0
        while i < params.count {
            let param = params[i]

            switch param {
            case 0: // Reset
                currentForeground = nil
                currentBackground = nil
                currentBold = false
                currentItalic = false
                currentUnderline = false

            case 1: // Bold
                currentBold = true

            case 3: // Italic
                currentItalic = true

            case 4: // Underline
                currentUnderline = true

            case 22: // Normal intensity
                currentBold = false

            case 23: // Not italic
                currentItalic = false

            case 24: // Not underlined
                currentUnderline = false

            case 30...37: // Foreground colors
                currentForeground = colorScheme.ansiColors[param - 30]

            case 38: // Extended foreground color
                if i + 2 < params.count && params[i + 1] == 5 {
                    // 256-color mode
                    let colorIndex = params[i + 2]
                    currentForeground = colorScheme.get256Color(colorIndex)
                    i += 2
                }

            case 40...47: // Background colors
                currentBackground = colorScheme.ansiColors[param - 40]

            case 48: // Extended background color
                if i + 2 < params.count && params[i + 1] == 5 {
                    // 256-color mode
                    let colorIndex = params[i + 2]
                    currentBackground = colorScheme.get256Color(colorIndex)
                    i += 2
                }

            case 90...97: // Bright foreground colors
                currentForeground = colorScheme.ansiBrightColors[param - 90]

            case 100...107: // Bright background colors
                currentBackground = colorScheme.ansiBrightColors[param - 100]

            default:
                break
            }

            i += 1
        }
    }

    private func eraseDisplay(mode: Int) {
        let emptyCell = TerminalCell(character: " ")

        switch mode {
        case 0: // Erase from cursor to end
            for x in cursorX..<cols {
                if cursorY < buffer.count && x < buffer[cursorY].count {
                    buffer[cursorY][x] = emptyCell
                }
            }
            for y in (cursorY + 1)..<rows {
                for x in 0..<cols {
                    if y < buffer.count && x < buffer[y].count {
                        buffer[y][x] = emptyCell
                    }
                }
            }

        case 1: // Erase from cursor to beginning
            for y in 0..<cursorY {
                for x in 0..<cols {
                    if y < buffer.count && x < buffer[y].count {
                        buffer[y][x] = emptyCell
                    }
                }
            }
            for x in 0...cursorX {
                if cursorY < buffer.count && x < buffer[cursorY].count {
                    buffer[cursorY][x] = emptyCell
                }
            }

        case 2, 3: // Erase entire display
            DispatchQueue.main.async { [weak self] in
                self?.initializeBuffer()
            }

        default:
            break
        }
    }

    private func eraseLine(mode: Int) {
        let emptyCell = TerminalCell(character: " ")

        guard cursorY < buffer.count else { return }

        switch mode {
        case 0: // Erase from cursor to end of line
            for x in cursorX..<cols {
                if x < buffer[cursorY].count {
                    buffer[cursorY][x] = emptyCell
                }
            }

        case 1: // Erase from cursor to beginning of line
            for x in 0...cursorX {
                if x < buffer[cursorY].count {
                    buffer[cursorY][x] = emptyCell
                }
            }

        case 2: // Erase entire line
            for x in 0..<cols {
                if x < buffer[cursorY].count {
                    buffer[cursorY][x] = emptyCell
                }
            }

        default:
            break
        }
    }

    private func scrollUp() {
        // Move first line to scrollback
        if buffer.count > 0 {
            scrollbackBuffer.append(buffer[0])
            if scrollbackBuffer.count > maxScrollback {
                scrollbackBuffer.removeFirst()
            }

            // Shift all lines up
            buffer.remove(at: 0)
            buffer.append(Array(repeating: TerminalCell(character: " "), count: cols))
        }
    }

    func handleInput(_ input: String) {
        onInput?(input)
    }

    func updateSelection(with gesture: DragGesture.Value) {
        // Implement text selection logic
    }

    deinit {
        updateTimer?.invalidate()
    }
}
