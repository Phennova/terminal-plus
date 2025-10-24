import SwiftUI
import Combine

struct TerminalPane: Identifiable {
    let id = UUID()
    var width: CGFloat
    var subPanes: [TerminalSubPane]
}

struct TerminalSubPane: Identifiable {
    let id = UUID()
    var height: CGFloat
}

class SplitPaneManager: ObservableObject {
    @Published var panes: [TerminalPane] = []
    @Published var activePane: UUID?

    init() {
        // Start with one pane
        let subPane = TerminalSubPane(height: 600)
        let pane = TerminalPane(width: 800, subPanes: [subPane])
        panes = [pane]
        activePane = pane.id
    }

    func addPane() {
        let subPane = TerminalSubPane(height: 600)
        let newPane = TerminalPane(width: 400, subPanes: [subPane])
        panes.append(newPane)
        activePane = newPane.id
        redistributeWidths()
    }

    func splitHorizontally() {
        guard let activePaneIndex = panes.firstIndex(where: { $0.id == activePane }) else { return }

        let currentWidth = panes[activePaneIndex].width
        panes[activePaneIndex].width = currentWidth / 2

        let subPane = TerminalSubPane(height: 600)
        let newPane = TerminalPane(width: currentWidth / 2, subPanes: [subPane])
        panes.insert(newPane, at: activePaneIndex + 1)
        activePane = newPane.id
    }

    func splitVertically() {
        guard let activePaneIndex = panes.firstIndex(where: { $0.id == activePane }) else { return }
        guard let activeSubPaneIndex = panes[activePaneIndex].subPanes.indices.last else { return }

        let currentHeight = panes[activePaneIndex].subPanes[activeSubPaneIndex].height
        panes[activePaneIndex].subPanes[activeSubPaneIndex].height = currentHeight / 2

        let newSubPane = TerminalSubPane(height: currentHeight / 2)
        panes[activePaneIndex].subPanes.append(newSubPane)
    }

    func closePane(_ paneId: UUID) {
        panes.removeAll { $0.id == paneId }
        if panes.isEmpty {
            addPane()
        } else {
            redistributeWidths()
            if activePane == paneId {
                activePane = panes.first?.id
            }
        }
    }

    func closeSubPane(paneId: UUID, subPaneId: UUID) {
        guard let paneIndex = panes.firstIndex(where: { $0.id == paneId }) else { return }
        panes[paneIndex].subPanes.removeAll { $0.id == subPaneId }

        if panes[paneIndex].subPanes.isEmpty {
            closePane(paneId)
        } else {
            redistributeHeights(for: paneIndex)
        }
    }

    private func redistributeWidths() {
        guard !panes.isEmpty else { return }
        let totalWidth: CGFloat = 800 // Default width, should be dynamic
        let widthPerPane = totalWidth / CGFloat(panes.count)

        for index in panes.indices {
            panes[index].width = widthPerPane
        }
    }

    private func redistributeHeights(for paneIndex: Int) {
        guard paneIndex < panes.count else { return }
        let totalHeight: CGFloat = 600 // Default height, should be dynamic
        let heightPerSubPane = totalHeight / CGFloat(panes[paneIndex].subPanes.count)

        for index in panes[paneIndex].subPanes.indices {
            panes[paneIndex].subPanes[index].height = heightPerSubPane
        }
    }

    func resizePane(_ paneId: UUID, width: CGFloat) {
        guard let index = panes.firstIndex(where: { $0.id == paneId }) else { return }
        panes[index].width = width
    }

    func resizeSubPane(paneId: UUID, subPaneId: UUID, height: CGFloat) {
        guard let paneIndex = panes.firstIndex(where: { $0.id == paneId }),
              let subPaneIndex = panes[paneIndex].subPanes.firstIndex(where: { $0.id == subPaneId }) else { return }
        panes[paneIndex].subPanes[subPaneIndex].height = height
    }
}
