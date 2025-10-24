import SwiftUI
import AppKit

struct TerminalView: View {
    let paneId: UUID
    @StateObject private var terminalEmulator = TerminalEmulator()
    @StateObject private var ptyController = PTYController()
    @StateObject private var previewManager = PreviewManager()
    @EnvironmentObject var gitIntegration: GitIntegration
    @EnvironmentObject var containerDetector: ContainerDetector
    @EnvironmentObject var timeTravelDebugger: TimeTravelDebugger
    @AppStorage("fontSize") private var fontSize = 14.0
    @State private var hoveredPath: String?

    var body: some View {
        VStack(spacing: 0) {
            // Status bar with git info and container status
            StatusBar(gitInfo: gitIntegration.currentBranch,
                     hasUncommittedChanges: gitIntegration.hasUncommittedChanges,
                     isInContainer: containerDetector.isInContainer,
                     containerName: containerDetector.containerName)

            // Terminal content with proper scrolling
            GeometryReader { geometry in
                TerminalContentView(
                    terminalEmulator: terminalEmulator,
                    ptyController: ptyController,
                    fontSize: fontSize,
                    viewSize: geometry.size
                )
            }
            .background(Color(nsColor: terminalEmulator.colorScheme.background))

            // Preview overlay
            if let path = hoveredPath, let preview = previewManager.getPreview(for: path) {
                PreviewOverlay(preview: preview)
                    .transition(.opacity)
            }
        }
        .onAppear {
            ptyController.start()
            ptyController.onOutput = { data in
                terminalEmulator.processOutput(data)
                timeTravelDebugger.recordOutput(data)
            }
            terminalEmulator.onInput = { text in
                ptyController.write(text)
                if let data = text.data(using: .utf8) {
                    timeTravelDebugger.recordInput(data)
                }
            }
            gitIntegration.startMonitoring(directory: ptyController.currentDirectory)
            containerDetector.startDetection()
        }
        .onDisappear {
            ptyController.stop()
            gitIntegration.stopMonitoring()
            containerDetector.stopDetection()
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
        terminalView.fontSize = CGFloat(fontSize)
        terminalView.viewWidth = viewSize.width
        terminalView.updateSize()
        terminalView.needsDisplay = true
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

        // Calculate required height based on buffer
        let contentHeight = CGFloat(emulator.buffer.count) * lineHeight
        let minHeight = max(contentHeight, 600)

        // Update frame size
        frame = NSRect(x: 0, y: 0, width: viewWidth, height: minHeight)

        // Notify PTY of size change
        let cols = columns
        let rows = max(24, Int(minHeight / lineHeight))
        ptyController?.resize(width: cols, height: rows)
        emulator.resize(rows: rows, cols: cols)
    }

    func scrollToBottom() {
        guard let scrollView = enclosingScrollView else { return }
        let bottomPoint = NSPoint(x: 0, y: frame.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: bottomPoint)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let terminalEmulator = terminalEmulator,
              let context = NSGraphicsContext.current?.cgContext else { return }

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // Draw terminal content from bottom to top (fix coordinate system)
        for (lineIndex, line) in terminalEmulator.buffer.enumerated() {
            // Calculate Y position from bottom
            let yPosition = CGFloat(terminalEmulator.buffer.count - lineIndex - 1) * lineHeight

            for (colIndex, cell) in line.enumerated() {
                let xPosition = CGFloat(colIndex) * charWidth
                let rect = NSRect(x: xPosition, y: yPosition, width: charWidth, height: lineHeight)

                // Draw background
                if let bgColor = cell.backgroundColor {
                    context.setFillColor(bgColor.cgColor)
                    context.fill(rect)
                }

                // Draw character
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: cell.foregroundColor ?? terminalEmulator.colorScheme.foreground
                ]

                let attributedString = NSAttributedString(string: String(cell.character), attributes: attributes)

                // Draw text with proper baseline
                attributedString.draw(at: NSPoint(x: xPosition, y: yPosition + 2))
            }
        }

        // Draw cursor
        if terminalEmulator.cursorVisible && cursorBlink {
            let cursorX = CGFloat(terminalEmulator.cursorX) * charWidth
            let cursorY = CGFloat(terminalEmulator.buffer.count - terminalEmulator.cursorY - 1) * lineHeight
            let cursorRect = NSRect(x: cursorX, y: cursorY, width: charWidth, height: lineHeight)

            context.setFillColor(terminalEmulator.colorScheme.cursor.cgColor)
            context.setAlpha(0.7)
            context.fill(cursorRect)
            context.setAlpha(1.0)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else { return }

        // Handle special keys
        if event.modifiers.contains(.command) {
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
