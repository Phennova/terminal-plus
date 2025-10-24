import SwiftUI

struct ContentView: View {
    @EnvironmentObject var splitPaneManager: SplitPaneManager
    @EnvironmentObject var snippetManager: SnippetManager
    @EnvironmentObject var packageManager: PackageManagerUI
    @EnvironmentObject var environmentManager: EnvironmentManager
    @EnvironmentObject var timeTravelDebugger: TimeTravelDebugger
    @State private var showCommandPalette = false
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {
            // Feature Toolbar
            FeatureToolbar(
                showCommandPalette: $showCommandPalette,
                showSnippets: $snippetManager.showManager,
                showEnvironment: $environmentManager.showManager,
                showPackages: $packageManager.showManager,
                showHistory: $timeTravelDebugger.showDebugger,
                showHelp: $showHelp
            )

            // Main content
            ZStack {
                // Main terminal view with split panes
                SplitPaneView()
                    .environmentObject(splitPaneManager)

                // Overlays
                if showCommandPalette {
                    CommandPaletteView(isPresented: $showCommandPalette)
                        .transition(.opacity)
                }

                if snippetManager.showManager {
                    SnippetManagerView()
                        .environmentObject(snippetManager)
                        .transition(.opacity)
                }

                if environmentManager.showManager {
                    EnvironmentManagerView()
                        .environmentObject(environmentManager)
                        .transition(.opacity)
                }

                if packageManager.showManager {
                    PackageManagerView()
                        .environmentObject(packageManager)
                        .transition(.opacity)
                }

                if timeTravelDebugger.showDebugger {
                    TimeTravelDebuggerView()
                        .environmentObject(timeTravelDebugger)
                        .transition(.opacity)
                }

                if showHelp {
                    HelpView(isPresented: $showHelp)
                        .transition(.opacity)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            withAnimation {
                showCommandPalette.toggle()
            }
        }
    }
}

struct FeatureToolbar: View {
    @Binding var showCommandPalette: Bool
    @Binding var showSnippets: Bool
    @Binding var showEnvironment: Bool
    @Binding var showPackages: Bool
    @Binding var showHistory: Bool
    @Binding var showHelp: Bool

    var body: some View {
        HStack(spacing: 8) {
            ToolbarButton(
                icon: "command",
                label: "Command Palette",
                shortcut: "⌘⇧P"
            ) {
                showCommandPalette.toggle()
            }

            ToolbarButton(
                icon: "doc.text",
                label: "Snippets",
                shortcut: "⌘⇧S"
            ) {
                showSnippets.toggle()
            }

            ToolbarButton(
                icon: "gearshape",
                label: "Environment",
                shortcut: "⌘⇧E"
            ) {
                showEnvironment.toggle()
            }

            ToolbarButton(
                icon: "shippingbox",
                label: "Packages",
                shortcut: "⌘⇧B"
            ) {
                showPackages.toggle()
            }

            ToolbarButton(
                icon: "clock.arrow.circlepath",
                label: "History",
                shortcut: "⌘⇧H"
            ) {
                showHistory.toggle()
            }

            Spacer()

            ToolbarButton(
                icon: "questionmark.circle",
                label: "Help",
                shortcut: "⌘/"
            ) {
                showHelp.toggle()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .help("\(label) (\(shortcut))")
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct HelpView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Terminal Plus - Keyboard Shortcuts")
                        .font(.headline)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Shortcuts list
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ShortcutSection(title: "Terminal") {
                            ShortcutRow(key: "⌘T", description: "New terminal tab")
                            ShortcutRow(key: "⌘D", description: "Split pane vertically")
                            ShortcutRow(key: "⌘⇧D", description: "Split pane horizontally")
                            ShortcutRow(key: "⌘K", description: "Clear terminal")
                        }

                        ShortcutSection(title: "Features") {
                            ShortcutRow(key: "⌘⇧P", description: "Command Palette - Quick access to commands")
                            ShortcutRow(key: "⌘⇧S", description: "Snippet Manager - Manage saved commands")
                            ShortcutRow(key: "⌘⇧E", description: "Environment Variables - Edit env vars")
                            ShortcutRow(key: "⌘⇧B", description: "Package Manager - Homebrew UI")
                            ShortcutRow(key: "⌘⇧H", description: "Time Travel - View command history")
                        }

                        ShortcutSection(title: "Smart Features") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Type 'j <directory>' for smart directory jumping")
                                    .font(.system(size: 12))
                                Text("• Hover over file paths to see previews")
                                    .font(.system(size: 12))
                                Text("• Git status shown in status bar automatically")
                                    .font(.system(size: 12))
                                Text("• Container detection when inside Docker/K8s")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.gray)
                        }

                        ShortcutSection(title: "Settings") {
                            ShortcutRow(key: "⌘,", description: "Open Settings")
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 600, height: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
            .shadow(radius: 20)
        }
    }
}

struct ShortcutSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)

            content
        }
    }
}

struct ShortcutRow: View {
    let key: String
    let description: String

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 11, design: .monospaced, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct SplitPaneView: View {
    @EnvironmentObject var splitPaneManager: SplitPaneManager

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(splitPaneManager.panes) { pane in
                    VStack(spacing: 0) {
                        ForEach(pane.subPanes) { subPane in
                            TerminalView(paneId: subPane.id)
                                .frame(height: subPane.height)

                            if subPane.id != pane.subPanes.last?.id {
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                            }
                        }
                    }
                    .frame(width: pane.width)

                    if pane.id != splitPaneManager.panes.last?.id {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
            }
        }
    }
}
