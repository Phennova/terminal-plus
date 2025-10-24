import Foundation
import SwiftUI

struct DirectoryEntry: Identifiable, Codable {
    let id: UUID
    let path: String
    let name: String
    var frequency: Int
    var lastAccessed: Date

    init(id: UUID = UUID(), path: String, name: String, frequency: Int = 1, lastAccessed: Date = Date()) {
        self.id = id
        self.path = path
        self.name = name
        self.frequency = frequency
        self.lastAccessed = lastAccessed
    }
}

class DirectoryJumper: ObservableObject {
    @Published var recentDirectories: [DirectoryEntry] = []
    @Published var frequentDirectories: [DirectoryEntry] = []

    private let maxRecent = 50
    private let saveKey = "DirectoryHistory"

    init() {
        loadHistory()
    }

    func recordVisit(to path: String) {
        let name = (path as NSString).lastPathComponent

        // Update or add to recent directories
        if let index = recentDirectories.firstIndex(where: { $0.path == path }) {
            recentDirectories[index].frequency += 1
            recentDirectories[index].lastAccessed = Date()
        } else {
            let entry = DirectoryEntry(path: path, name: name)
            recentDirectories.insert(entry, at: 0)
        }

        // Keep only recent entries
        if recentDirectories.count > maxRecent {
            recentDirectories.removeLast()
        }

        // Update frequent directories (sorted by frequency)
        updateFrequentDirectories()

        saveHistory()
    }

    private func updateFrequentDirectories() {
        frequentDirectories = recentDirectories
            .sorted { $0.frequency > $1.frequency }
            .prefix(20)
            .map { $0 }
    }

    func fuzzySearch(query: String) -> [DirectoryEntry] {
        guard !query.isEmpty else { return recentDirectories }

        return recentDirectories.filter { entry in
            // Match path components
            let pathComponents = entry.path.split(separator: "/").map { String($0) }
            return pathComponents.contains { component in
                component.localizedCaseInsensitiveContains(query)
            }
        }
    }

    func getJumpCommand(to path: String) -> String {
        return "cd \"\(path)\""
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(recentDirectories) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([DirectoryEntry].self, from: data) {
            recentDirectories = decoded
            updateFrequentDirectories()
        }
    }

    // Parse common directory jumping commands
    func shouldInterceptCommand(_ command: String) -> String? {
        // Handle "j" or "jump" commands for quick directory jumping
        if command.hasPrefix("j ") || command.hasPrefix("jump ") {
            let query = command.split(separator: " ", maxSplits: 1).last.map(String.init) ?? ""
            let matches = fuzzySearch(query: query)

            if let first = matches.first {
                return getJumpCommand(to: first.path)
            }
        }

        return nil
    }
}
