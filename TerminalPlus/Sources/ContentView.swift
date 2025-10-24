import SwiftUI

struct ContentView: View {
    @EnvironmentObject var splitPaneManager: SplitPaneManager
    @EnvironmentObject var snippetManager: SnippetManager
    @EnvironmentObject var packageManager: PackageManagerUI
    @EnvironmentObject var environmentManager: EnvironmentManager
    @EnvironmentObject var timeTravelDebugger: TimeTravelDebugger
    @State private var showCommandPalette = false

    var body: some View {
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            withAnimation {
                showCommandPalette.toggle()
            }
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
