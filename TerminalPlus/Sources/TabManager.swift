import Foundation
import SwiftUI

class TabSession: Identifiable {
    let id = UUID()
    var title: String
    let terminalEmulator: TerminalEmulator
    let ptyController: PTYController
    let previewManager: PreviewManager

    init(title: String) {
        self.title = title
        self.terminalEmulator = TerminalEmulator()
        self.ptyController = PTYController()
        self.previewManager = PreviewManager()

        // Set up connections
        ptyController.onOutput = { [weak terminalEmulator] data in
            terminalEmulator?.processOutput(data)
        }

        terminalEmulator.onInput = { [weak ptyController] text in
            ptyController?.write(text)
        }
    }

    func start() {
        ptyController.start()
    }

    func stop() {
        ptyController.stop()
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [TabSession] = []
    @Published var selectedIndex: Int = 0

    var selectedTab: TabSession? {
        guard tabs.indices.contains(selectedIndex) else { return nil }
        return tabs[selectedIndex]
    }

    init() {
        addNewTab()
    }

    func addNewTab() {
        let newTab = TabSession(title: "Terminal \(tabs.count + 1)")
        tabs.append(newTab)
        selectedIndex = tabs.count - 1
        newTab.start()
    }

    func closeTab(at index: Int) {
        guard tabs.count > 1, tabs.indices.contains(index) else { return }

        // Stop the tab
        tabs[index].stop()

        // Remove it
        tabs.remove(at: index)

        // Adjust selected index
        if selectedIndex >= tabs.count {
            selectedIndex = tabs.count - 1
        }
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectedIndex = index
    }
}
