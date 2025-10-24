import SwiftUI

@main
struct TerminalPlusApp: App {
    @StateObject private var splitPaneManager = SplitPaneManager()
    @StateObject private var snippetManager = SnippetManager()
    @StateObject private var gitIntegration = GitIntegration()
    @StateObject private var timeTravelDebugger = TimeTravelDebugger()
    @StateObject private var directoryJumper = DirectoryJumper()
    @StateObject private var packageManager = PackageManagerUI()
    @StateObject private var containerDetector = ContainerDetector()
    @StateObject private var environmentManager = EnvironmentManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(splitPaneManager)
                .environmentObject(snippetManager)
                .environmentObject(gitIntegration)
                .environmentObject(timeTravelDebugger)
                .environmentObject(directoryJumper)
                .environmentObject(packageManager)
                .environmentObject(containerDetector)
                .environmentObject(environmentManager)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Terminal Tab") {
                    splitPaneManager.addPane()
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button("Split Pane Horizontally") {
                    splitPaneManager.splitHorizontally()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Split Pane Vertically") {
                    splitPaneManager.splitVertically()
                }
                .keyboardShortcut("d", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("Command Palette...") {
                    NotificationCenter.default.post(name: .showCommandPalette, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Button("Snippet Manager...") {
                    snippetManager.showManager.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Environment Variables...") {
                    environmentManager.showManager.toggle()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Package Manager...") {
                    packageManager.showManager.toggle()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button("Time Travel Debugger...") {
                    timeTravelDebugger.showDebugger.toggle()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("fontFamily") private var fontFamily = "Menlo"
    @AppStorage("cursorBlinkEnabled") private var cursorBlinkEnabled = true
    @AppStorage("colorScheme") private var colorScheme = "Dark"

    var body: some View {
        TabView {
            Form {
                Section("Appearance") {
                    Picker("Color Scheme", selection: $colorScheme) {
                        Text("Dark").tag("Dark")
                        Text("Light").tag("Light")
                        Text("Solarized Dark").tag("Solarized Dark")
                        Text("Solarized Light").tag("Solarized Light")
                    }

                    Slider(value: $fontSize, in: 10...24, step: 1) {
                        Text("Font Size: \(Int(fontSize))pt")
                    }

                    Picker("Font Family", selection: $fontFamily) {
                        Text("Menlo").tag("Menlo")
                        Text("Monaco").tag("Monaco")
                        Text("SF Mono").tag("SF Mono")
                        Text("Courier New").tag("Courier New")
                    }

                    Toggle("Cursor Blink", isOn: $cursorBlinkEnabled)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
        }
        .frame(width: 500, height: 400)
    }
}

extension Notification.Name {
    static let showCommandPalette = Notification.Name("showCommandPalette")
}
