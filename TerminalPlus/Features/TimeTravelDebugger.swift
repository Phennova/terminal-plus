import Foundation
import SwiftUI

struct CommandHistoryEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let command: String
    let output: String
    let exitCode: Int?
    let workingDirectory: String

    init(id: UUID = UUID(), timestamp: Date = Date(), command: String, output: String, exitCode: Int? = nil, workingDirectory: String) {
        self.id = id
        self.timestamp = timestamp
        self.command = command
        self.output = output
        self.exitCode = exitCode
        self.workingDirectory = workingDirectory
    }
}

class TimeTravelDebugger: ObservableObject {
    @Published var history: [CommandHistoryEntry] = []
    @Published var showDebugger: Bool = false
    @Published var selectedEntry: CommandHistoryEntry?

    private let maxHistorySize = 1000
    private var currentCommand: String = ""
    private var currentOutput: String = ""

    func recordInput(_ data: Data) {
        if let input = String(data: data, encoding: .utf8) {
            currentCommand += input

            // If command ends with newline, save it
            if input.contains("\n") {
                // Command is complete, waiting for output
            }
        }
    }

    func recordOutput(_ data: Data) {
        if let output = String(data: data, encoding: .utf8) {
            currentOutput += output
        }
    }

    func saveCommand(workingDirectory: String, exitCode: Int? = nil) {
        guard !currentCommand.isEmpty else { return }

        let entry = CommandHistoryEntry(
            command: currentCommand.trimmingCharacters(in: .whitespacesAndNewlines),
            output: currentOutput,
            exitCode: exitCode,
            workingDirectory: workingDirectory
        )

        history.append(entry)

        // Limit history size
        if history.count > maxHistorySize {
            history.removeFirst(history.count - maxHistorySize)
        }

        // Reset current command and output
        currentCommand = ""
        currentOutput = ""

        // Save to disk
        saveHistory()
    }

    func searchHistory(query: String) -> [CommandHistoryEntry] {
        history.filter {
            $0.command.localizedCaseInsensitiveContains(query) ||
            $0.output.localizedCaseInsensitiveContains(query)
        }
    }

    func getHistoryForDirectory(_ directory: String) -> [CommandHistoryEntry] {
        history.filter { $0.workingDirectory == directory }
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private func saveHistory() {
        // Save recent 100 entries to UserDefaults
        let recentHistory = Array(history.suffix(100))
        if let encoded = try? JSONEncoder().encode(recentHistory) {
            UserDefaults.standard.set(encoded, forKey: "CommandHistory")
        }
    }

    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "CommandHistory"),
           let decoded = try? JSONDecoder().decode([CommandHistoryEntry].self, from: data) {
            history = decoded
        }
    }
}

struct TimeTravelDebuggerView: View {
    @EnvironmentObject var debugger: TimeTravelDebugger
    @State private var searchText: String = ""
    @State private var selectedEntry: CommandHistoryEntry?

    private var filteredHistory: [CommandHistoryEntry] {
        if searchText.isEmpty {
            return debugger.history.reversed()
        }
        return debugger.searchHistory(query: searchText).reversed()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    debugger.showDebugger = false
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Time Travel Debugger")
                        .font(.headline)
                    Spacer()
                    Button(action: { debugger.clearHistory() }) {
                        Text("Clear")
                    }
                    Button(action: { debugger.showDebugger = false }) {
                        Image(systemName: "xmark")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search commands...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()

                Divider()

                HSplitView {
                    // History list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(filteredHistory) { entry in
                                HistoryEntryRow(entry: entry, isSelected: selectedEntry?.id == entry.id)
                                    .onTapGesture {
                                        selectedEntry = entry
                                    }
                            }
                        }
                        .padding()
                    }
                    .frame(minWidth: 300)

                    // Detail view
                    if let entry = selectedEntry {
                        HistoryDetailView(entry: entry)
                    } else {
                        Text("Select a command to view details")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(width: 900, height: 600)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
            .shadow(radius: 20)
        }
    }
}

struct HistoryEntryRow: View {
    let entry: CommandHistoryEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.command)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)

                Spacer()

                if let exitCode = entry.exitCode {
                    Circle()
                        .fill(exitCode == 0 ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
            }

            Text(formatDate(entry.timestamp))
                .font(.system(size: 11))
                .foregroundColor(.gray)

            Text(entry.workingDirectory)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct HistoryDetailView: View {
    let entry: CommandHistoryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Command")
                        .font(.headline)
                    Text(entry.command)
                        .font(.system(size: 13, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Output")
                        .font(.headline)
                    ScrollView {
                        Text(entry.output.isEmpty ? "No output" : entry.output)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Directory")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(entry.workingDirectory)
                            .font(.system(size: 11, design: .monospaced))
                    }

                    Spacer()

                    if let exitCode = entry.exitCode {
                        VStack(alignment: .leading) {
                            Text("Exit Code")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(exitCode)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(exitCode == 0 ? .green : .red)
                        }
                    }
                }

                Button("Copy Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.command, forType: .string)
                }
            }
            .padding()
        }
    }
}
