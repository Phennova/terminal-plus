import Foundation
import SwiftUI

struct EnvironmentVariable: Identifiable {
    let id = UUID()
    var key: String
    var value: String
    var isModified: Bool = false
}

class EnvironmentManager: ObservableObject {
    @Published var variables: [EnvironmentVariable] = []
    @Published var showManager: Bool = false
    @Published var searchText: String = ""

    init() {
        loadEnvironmentVariables()
    }

    func loadEnvironmentVariables() {
        let environment = ProcessInfo.processInfo.environment
        variables = environment.map { key, value in
            EnvironmentVariable(key: key, value: value)
        }.sorted { $0.key < $1.key }
    }

    func addVariable(key: String, value: String) {
        // Add to current process
        setenv(key, value, 1)

        // Update list
        if let index = variables.firstIndex(where: { $0.key == key }) {
            variables[index].value = value
            variables[index].isModified = true
        } else {
            var newVar = EnvironmentVariable(key: key, value: value)
            newVar.isModified = true
            variables.append(newVar)
            variables.sort { $0.key < $1.key }
        }

        // Save to shell profile
        saveToShellProfile(key: key, value: value)
    }

    func removeVariable(_ variable: EnvironmentVariable) {
        unsetenv(variable.key)
        variables.removeAll { $0.id == variable.id }
        removeFromShellProfile(key: variable.key)
    }

    func updateVariable(_ variable: EnvironmentVariable, newValue: String) {
        setenv(variable.key, newValue, 1)

        if let index = variables.firstIndex(where: { $0.id == variable.id }) {
            variables[index].value = newValue
            variables[index].isModified = true
        }

        saveToShellProfile(key: variable.key, value: newValue)
    }

    private func saveToShellProfile(key: String, value: String) {
        // Determine shell config file
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        var configFile: String
        if shell.contains("zsh") {
            configFile = "\(home)/.zshrc"
        } else if shell.contains("bash") {
            configFile = "\(home)/.bashrc"
        } else {
            configFile = "\(home)/.profile"
        }

        // Append export command
        let exportLine = "export \(key)=\"\(value)\"\n"

        do {
            if FileManager.default.fileExists(atPath: configFile) {
                let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: configFile))
                fileHandle.seekToEndOfFile()
                fileHandle.write(exportLine.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try exportLine.write(toFile: configFile, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to save to shell profile: \(error)")
        }
    }

    private func removeFromShellProfile(key: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        var configFile: String
        if shell.contains("zsh") {
            configFile = "\(home)/.zshrc"
        } else if shell.contains("bash") {
            configFile = "\(home)/.bashrc"
        } else {
            configFile = "\(home)/.profile"
        }

        do {
            if FileManager.default.fileExists(atPath: configFile) {
                let content = try String(contentsOfFile: configFile, encoding: .utf8)
                let lines = content.split(separator: "\n")
                let filtered = lines.filter { !$0.contains("export \(key)=") }
                let newContent = filtered.joined(separator: "\n") + "\n"
                try newContent.write(toFile: configFile, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to remove from shell profile: \(error)")
        }
    }

    func exportToFile(path: String) throws {
        let content = variables.map { "export \($0.key)=\"\($0.value)\"" }.joined(separator: "\n")
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    func importFromFile(path: String) throws {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.split(separator: "\n")

        for line in lines {
            if line.hasPrefix("export ") {
                let exportLine = line.dropFirst(7) // Remove "export "
                let components = exportLine.split(separator: "=", maxSplits: 1)

                if components.count == 2 {
                    let key = String(components[0])
                    var value = String(components[1])

                    // Remove quotes
                    if value.hasPrefix("\"") && value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    }

                    addVariable(key: key, value: value)
                }
            }
        }
    }
}

struct EnvironmentManagerView: View {
    @EnvironmentObject var environmentManager: EnvironmentManager
    @State private var showingAddVariable = false
    @State private var editingVariable: EnvironmentVariable?

    private var filteredVariables: [EnvironmentVariable] {
        if environmentManager.searchText.isEmpty {
            return environmentManager.variables
        }
        return environmentManager.variables.filter {
            $0.key.localizedCaseInsensitiveContains(environmentManager.searchText) ||
            $0.value.localizedCaseInsensitiveContains(environmentManager.searchText)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    environmentManager.showManager = false
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Environment Variables")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingAddVariable = true }) {
                        Image(systemName: "plus")
                    }
                    Button(action: { environmentManager.loadEnvironmentVariables() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button(action: { environmentManager.showManager = false }) {
                        Image(systemName: "xmark")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search variables...", text: $environmentManager.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()

                Divider()

                // Variables list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredVariables) { variable in
                            EnvironmentVariableRow(variable: variable) {
                                editingVariable = variable
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 700, height: 600)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
            .shadow(radius: 20)

            if showingAddVariable {
                EnvironmentVariableEditor(
                    variable: nil,
                    isPresented: $showingAddVariable
                )
                .environmentObject(environmentManager)
            }

            if let variable = editingVariable {
                EnvironmentVariableEditor(
                    variable: variable,
                    isPresented: .init(
                        get: { editingVariable != nil },
                        set: { if !$0 { editingVariable = nil } }
                    )
                )
                .environmentObject(environmentManager)
            }
        }
    }
}

struct EnvironmentVariableRow: View {
    @EnvironmentObject var environmentManager: EnvironmentManager
    let variable: EnvironmentVariable
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(variable.key)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))

                    if variable.isModified {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(variable.value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(variable.value, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)

            Button(action: {
                environmentManager.removeVariable(variable)
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct EnvironmentVariableEditor: View {
    @EnvironmentObject var environmentManager: EnvironmentManager
    @Binding var isPresented: Bool

    @State private var key: String
    @State private var value: String

    let variable: EnvironmentVariable?

    init(variable: EnvironmentVariable?, isPresented: Binding<Bool>) {
        self.variable = variable
        self._isPresented = isPresented
        self._key = State(initialValue: variable?.key ?? "")
        self._value = State(initialValue: variable?.value ?? "")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                Text(variable == nil ? "New Environment Variable" : "Edit Environment Variable")
                    .font(.headline)

                TextField("Key", text: $key)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(variable != nil) // Don't allow editing key for existing variables

                TextEditor(text: $value)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3))

                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Save") {
                        if let existing = variable {
                            environmentManager.updateVariable(existing, newValue: value)
                        } else {
                            environmentManager.addVariable(key: key, value: value)
                        }
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(key.isEmpty)
                }
            }
            .padding()
            .frame(width: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
        }
    }
}
