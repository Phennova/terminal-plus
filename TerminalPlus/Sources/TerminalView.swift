import SwiftUI
import AppKit

struct TerminalView: View {
    @ObservedObject var tabSession: TabSession
    let viewSize: CGSize
    @EnvironmentObject var gitIntegration: GitIntegration
    @EnvironmentObject var containerDetector: ContainerDetector
    @EnvironmentObject var timeTravelDebugger: TimeTravelDebugger
    @AppStorage("fontSize") private var fontSize = 14.0
    @State private var hoveredPath: String?
    @State private var hasStarted = false

    var body: some View {
        VStack(spacing: 0) {
            // Status bar with git info and container status
            StatusBar(gitInfo: gitIntegration.currentBranch,
                     hasUncommittedChanges: gitIntegration.hasUncommittedChanges,
                     isInContainer: containerDetector.isInContainer,
                     containerName: containerDetector.containerName)

            // Terminal content with proper scrolling
            TerminalContentView(
                terminalEmulator: tabSession.terminalEmulator,
                ptyController: tabSession.ptyController,
                fontSize: fontSize,
                viewSize: viewSize
            )
            .background(Color(nsColor: tabSession.terminalEmulator.colorScheme.background))

            // Preview overlay
            if let path = hoveredPath, let preview = tabSession.previewManager.getPreview(for: path) {
                PreviewOverlay(preview: preview)
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Only start once
            if !hasStarted {
                hasStarted = true
                // Connect to time travel debugger
                tabSession.ptyController.onOutput = { [weak tabSession] data in
                    tabSession?.terminalEmulator.processOutput(data)
                    timeTravelDebugger.recordOutput(data)
                }
                tabSession.terminalEmulator.onInput = { [weak tabSession] text in
                    tabSession?.ptyController.write(text)
                    if let data = text.data(using: .utf8) {
                        timeTravelDebugger.recordInput(data)
                    }
                }
                gitIntegration.startMonitoring(directory: tabSession.ptyController.currentDirectory)
                containerDetector.startDetection()
            }
        }
    }
}

struct TerminalContentView: NSViewRepresentable {
    @ObservedObject var terminalEmulator: TerminalEmulator
    @ObservedObject var ptyController: PTYController
    let fontSize: Double
    let viewSize: CGSize

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.backgroundColor = .black

        let terminalView = TerminalNSView()
        terminalView.terminalEmulator = terminalEmulator
        terminalView.ptyController = ptyController
        terminalView.fontSize = CGFloat(fontSize)

        scrollView.documentView = terminalView

        // Set up automatic scrolling to bottom
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in
            // Auto-scroll to bottom when new content arrives
            if terminalView.shouldAutoScroll {
                terminalView.scrollToBottom()
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let terminalView = scrollView.documentView as? TerminalNSView else { return }

        let newFontSize = CGFloat(fontSize)
        let newWidth = viewSize.width

        // Only update if values actually changed
        let sizeChanged = abs(terminalView.fontSize - newFontSize) > 0.01 ||
                         abs(terminalView.viewWidth - newWidth) > 1.0

        if sizeChanged {
            terminalView.fontSize = newFontSize
            terminalView.viewWidth = newWidth
            terminalView.updateSize()
        }
    }
}

class TerminalNSView: NSView {
    var terminalEmulator: TerminalEmulator?
    var ptyController: PTYController?
    var fontSize: CGFloat = 14.0
    var viewWidth: CGFloat = 800.0
    var shouldAutoScroll = true
    private var cursorTimer: Timer?
    private var cursorBlink = true
    private var lastCols: Int = 0
    private var lastRows: Int = 0

    // Use flipped coordinate system (top-left origin)
    override var isFlipped: Bool { true }

    private var charWidth: CGFloat {
        fontSize * 0.6
    }

    private var lineHeight: CGFloat {
        fontSize * 1.4
    }

    private var columns: Int {
        max(1, Int(viewWidth / charWidth))
    }

    private var rows: Int {
        guard let emulator = terminalEmulator else { return 24 }
        return max(24, emulator.buffer.count)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        // Setup cursor blinking
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.cursorBlink.toggle()
            self?.needsDisplay = true
        }
    }

    func updateSize() {
        guard let emulator = terminalEmulator else { return }

        // Calculate required height based on scrollback + buffer
        let totalLines = emulator.scrollbackBuffer.count + emulator.buffer.count
        let contentHeight = CGFloat(totalLines) * lineHeight
        let minHeight = max(contentHeight, 600)

        // Update frame size to include all content (scrollback + visible buffer)
        frame = NSRect(x: 0, y: 0, width: viewWidth, height: minHeight)

        // Only notify PTY if size actually changed (PTY only cares about visible rows)
        let cols = columns
        let rows = max(24, emulator.buffer.count)

        if cols != lastCols || rows != lastRows {
            lastCols = cols
            lastRows = rows
            ptyController?.resize(width: cols, height: rows)
            emulator.resize(rows: rows, cols: cols)
        }

        // Request redraw
        needsDisplay = true
    }

    func scrollToBottom() {
        guard let scrollView = enclosingScrollView else { return }
        let bottomPoint = NSPoint(x: 0, y: frame.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: bottomPoint)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let terminalEmulator = terminalEmulator else { return }

        // Fill background
        terminalEmulator.colorScheme.background.setFill()
        dirtyRect.fill()

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        var currentLineIndex = 0

        // Draw scrollback buffer first
        for (scrollbackIndex, line) in terminalEmulator.scrollbackBuffer.enumerated() {
            let yPosition = CGFloat(currentLineIndex) * lineHeight

            // Skip lines outside dirtyRect for performance
            if yPosition + lineHeight < dirtyRect.minY || yPosition > dirtyRect.maxY {
                currentLineIndex += 1
                continue
            }

            for (colIndex, cell) in line.enumerated() {
                let xPosition = CGFloat(colIndex) * charWidth
                let rect = NSRect(x: xPosition, y: yPosition, width: charWidth, height: lineHeight)

                // Draw cell background
                if let bgColor = cell.backgroundColor {
                    context.setFillColor(bgColor.cgColor)
                    context.fill(rect)
                }

                // Draw character (skip spaces for performance)
                if cell.character != " " {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: cell.foregroundColor ?? terminalEmulator.colorScheme.foreground
                    ]

                    let attributedString = NSAttributedString(string: String(cell.character), attributes: attributes)
                    attributedString.draw(at: NSPoint(x: xPosition, y: yPosition))
                }
            }
            currentLineIndex += 1
        }

        // Draw current buffer
        for (bufferIndex, line) in terminalEmulator.buffer.enumerated() {
            let yPosition = CGFloat(currentLineIndex) * lineHeight

            // Skip lines outside dirtyRect for performance
            if yPosition + lineHeight < dirtyRect.minY || yPosition > dirtyRect.maxY {
                currentLineIndex += 1
                continue
            }

            for (colIndex, cell) in line.enumerated() {
                let xPosition = CGFloat(colIndex) * charWidth
                let rect = NSRect(x: xPosition, y: yPosition, width: charWidth, height: lineHeight)

                // Draw cell background
                if let bgColor = cell.backgroundColor {
                    context.setFillColor(bgColor.cgColor)
                    context.fill(rect)
                }

                // Draw character (skip spaces for performance)
                if cell.character != " " {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: cell.foregroundColor ?? terminalEmulator.colorScheme.foreground
                    ]

                    let attributedString = NSAttributedString(string: String(cell.character), attributes: attributes)
                    attributedString.draw(at: NSPoint(x: xPosition, y: yPosition))
                }
            }

            // Draw cursor on current buffer line
            if terminalEmulator.cursorVisible && cursorBlink && bufferIndex == terminalEmulator.cursorY {
                let cursorX = CGFloat(terminalEmulator.cursorX) * charWidth
                let cursorY = yPosition
                let cursorRect = NSRect(x: cursorX, y: cursorY, width: charWidth, height: lineHeight)

                context.setFillColor(terminalEmulator.colorScheme.cursor.cgColor)
                context.setAlpha(0.7)
                context.fill(cursorRect)
                context.setAlpha(1.0)
            }

            currentLineIndex += 1
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else { return }

        // Handle special keys
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }

        var output = characters

        // Convert special keys to ANSI sequences
        if let specialKey = event.specialKey {
            switch specialKey {
            case .upArrow:
                output = "\u{1B}[A"
            case .downArrow:
                output = "\u{1B}[B"
            case .rightArrow:
                output = "\u{1B}[C"
            case .leftArrow:
                output = "\u{1B}[D"
            case .home:
                output = "\u{1B}[H"
            case .end:
                output = "\u{1B}[F"
            case .delete:
                output = "\u{7F}"
            case .deleteForward:
                output = "\u{1B}[3~"
            case .pageUp:
                output = "\u{1B}[5~"
            case .pageDown:
                output = "\u{1B}[6~"
            default:
                break
            }
        }

        terminalEmulator?.handleInput(output)

        // Scroll to bottom when user types
        scrollToBottom()
    }

    deinit {
        cursorTimer?.invalidate()
    }
}

struct StatusBar: View {
    let gitInfo: String?
    let hasUncommittedChanges: Bool
    let isInContainer: Bool
    let containerName: String?

    var body: some View {
        HStack(spacing: 12) {
            // Git status
            if let branch = gitInfo {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.green)
                    Text(branch)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)

                    if hasUncommittedChanges {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            Spacer()

            // Container status
            if isInContainer, let name = containerName {
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.blue)
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(white: 0.15))
    }
}

struct PreviewOverlay: View {
    let preview: FilePreview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preview.fileName)
                .font(.headline)
                .foregroundColor(.white)

            if let image = preview.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 300)
            } else if let text = preview.text {
                ScrollView {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: 400, maxHeight: 300)
            }
        }
        .padding()
        .background(Color(white: 0.1).opacity(0.95))
        .cornerRadius(8)
        .shadow(radius: 10)
    }
}
