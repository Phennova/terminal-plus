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

            // Terminal content
            TerminalContentView(
                terminalEmulator: terminalEmulator,
                fontSize: fontSize,
                hoveredPath: $hoveredPath
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Handle text selection
                        terminalEmulator.updateSelection(with: value)
                    }
            )
            .onHover { hovering in
                if hovering {
                    detectFilePathsUnderCursor()
                }
            }

            // Preview overlay
            if let path = hoveredPath, let preview = previewManager.getPreview(for: path) {
                PreviewOverlay(preview: preview)
                    .transition(.opacity)
            }
        }
        .background(Color(nsColor: terminalEmulator.colorScheme.background))
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

    private func detectFilePathsUnderCursor() {
        // Implement file path detection logic
        // This would parse the current line and detect file paths
    }
}

struct TerminalContentView: NSViewRepresentable {
    @ObservedObject var terminalEmulator: TerminalEmulator
    let fontSize: Double
    @Binding var hoveredPath: String?

    func makeNSView(context: Context) -> TerminalNSView {
        let view = TerminalNSView()
        view.terminalEmulator = terminalEmulator
        view.fontSize = CGFloat(fontSize)
        return view
    }

    func updateNSView(_ nsView: TerminalNSView, context: Context) {
        nsView.fontSize = CGFloat(fontSize)
        nsView.needsDisplay = true
    }
}

class TerminalNSView: NSView {
    var terminalEmulator: TerminalEmulator?
    var fontSize: CGFloat = 14.0
    private var cursorTimer: Timer?

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
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let terminalEmulator = terminalEmulator else { return }

        let context = NSGraphicsContext.current?.cgContext
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let lineHeight = fontSize * 1.4

        // Draw terminal content
        for (lineIndex, line) in terminalEmulator.buffer.enumerated() {
            let yPosition = CGFloat(lineIndex) * lineHeight

            for (colIndex, cell) in line.enumerated() {
                let xPosition = CGFloat(colIndex) * (fontSize * 0.6)
                let rect = NSRect(x: xPosition, y: yPosition, width: fontSize * 0.6, height: lineHeight)

                // Draw background
                if let bgColor = cell.backgroundColor {
                    context?.setFillColor(bgColor.cgColor)
                    context?.fill(rect)
                }

                // Draw character
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: cell.foregroundColor ?? terminalEmulator.colorScheme.foreground
                ]

                let attributedString = NSAttributedString(string: String(cell.character), attributes: attributes)
                attributedString.draw(at: NSPoint(x: xPosition, y: yPosition))
            }
        }

        // Draw cursor
        if terminalEmulator.cursorVisible {
            let cursorX = CGFloat(terminalEmulator.cursorX) * (fontSize * 0.6)
            let cursorY = CGFloat(terminalEmulator.cursorY) * lineHeight
            let cursorRect = NSRect(x: cursorX, y: cursorY, width: fontSize * 0.6, height: lineHeight)

            context?.setFillColor(terminalEmulator.colorScheme.cursor.cgColor)
            context?.fill(cursorRect)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else { return }
        terminalEmulator?.handleInput(characters)
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
