import SwiftUI

struct ContentView: View {
    @EnvironmentObject var splitPaneManager: SplitPaneManager
    @EnvironmentObject var snippetManager: SnippetManager
    @EnvironmentObject var packageManager: PackageManagerUI
    @EnvironmentObject var environmentManager: EnvironmentManager
    @EnvironmentObject var timeTravelDebugger: TimeTravelDebugger
    @State private var showCommandPalette = false
    @State private var showHelp = false
    @State private var selectedTab = 0
    @State private var tabs: [TerminalTab] = []

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

            // Tab Bar
            TabBar(tabs: $tabs, selectedTab: $selectedTab)

            // Main content
            ZStack {
                // Terminal view
                GeometryReader { geometry in
                    if tabs.indices.contains(selectedTab) {
                        TerminalView(paneId: tabs[selectedTab].id)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }

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
        .onAppear {
            if tabs.isEmpty {
                addNewTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            withAnimation {
                showCommandPalette.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewTerminalTab"))) { _ in
            addNewTab()
        }
    }

    private func addNewTab() {
        let newTab = TerminalTab(title: "Terminal \(tabs.count + 1)")
        tabs.append(newTab)
        selectedTab = tabs.count - 1
    }
}

struct TerminalTab: Identifiable {
    let id = UUID()
    var title: String
}

struct TabBar: View {
    @Binding var tabs: [TerminalTab]
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                TabButton(
                    title: tab.title,
                    isSelected: index == selectedTab,
                    onSelect: {
                        selectedTab = index
                    },
                    onClose: {
                        if tabs.count > 1 {
                            tabs.remove(at: index)
                            if selectedTab >= tabs.count {
                                selectedTab = tabs.count - 1
                            }
                        }
                    }
                )
            }

            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("NewTerminalTab"), object: nil)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .background(Color(white: 0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white)

            if isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
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
                .font(.system(size: 11, weight: .medium, design: .monospaced))
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
