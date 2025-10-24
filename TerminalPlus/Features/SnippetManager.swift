import SwiftUI
import Combine

struct Snippet: Identifiable, Codable {
    let id: UUID
    var name: String
    var command: String
    var variables: [String] // Variable names like {{VAR_NAME}}
    var category: String

    init(id: UUID = UUID(), name: String, command: String, variables: [String] = [], category: String = "General") {
        self.id = id
        self.name = name
        self.command = command
        self.variables = variables
        self.category = category
    }
}

class SnippetManager: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var showManager: Bool = false

    private let saveKey = "SavedSnippets"

    init() {
        loadSnippets()
        createDefaultSnippets()
    }

    private func createDefaultSnippets() {
        if snippets.isEmpty {
            snippets = [
                Snippet(
                    name: "Git Status with Diff",
                    command: "git status && git diff",
                    category: "Git"
                ),
                Snippet(
                    name: "Find Files",
                    command: "find . -name '{{PATTERN}}' -type f",
                    variables: ["PATTERN"],
                    category: "Search"
                ),
                Snippet(
                    name: "Docker Run",
                    command: "docker run -it --rm --name {{NAME}} {{IMAGE}}",
                    variables: ["NAME", "IMAGE"],
                    category: "Docker"
                ),
                Snippet(
                    name: "Grep in Files",
                    command: "grep -r '{{PATTERN}}' {{PATH}}",
                    variables: ["PATTERN", "PATH"],
                    category: "Search"
                ),
                Snippet(
                    name: "SSH Connect",
                    command: "ssh {{USER}}@{{HOST}}",
                    variables: ["USER", "HOST"],
                    category: "Network"
                ),
                Snippet(
                    name: "Create and Enter Directory",
                    command: "mkdir -p {{DIR}} && cd {{DIR}}",
                    variables: ["DIR"],
                    category: "File System"
                ),
                Snippet(
                    name: "Watch Command",
                    command: "watch -n {{INTERVAL}} {{COMMAND}}",
                    variables: ["INTERVAL", "COMMAND"],
                    category: "Monitoring"
                ),
                Snippet(
                    name: "Compress Directory",
                    command: "tar -czf {{OUTPUT}}.tar.gz {{DIRECTORY}}",
                    variables: ["OUTPUT", "DIRECTORY"],
                    category: "File System"
                )
            ]
            saveSnippets()
        }
    }

    func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        saveSnippets()
    }

    func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            saveSnippets()
        }
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets()
    }

    func expandSnippet(_ snippet: Snippet, variables: [String: String]) -> String {
        var command = snippet.command

        for (key, value) in variables {
            command = command.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        return command
    }

    private func saveSnippets() {
        if let encoded = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func loadSnippets() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
        }
    }
}

struct SnippetManagerView: View {
    @EnvironmentObject var snippetManager: SnippetManager
    @State private var selectedSnippet: Snippet?
    @State private var showingEditor = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    snippetManager.showManager = false
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Snippet Manager")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingEditor = true }) {
                        Image(systemName: "plus")
                    }
                    Button(action: { snippetManager.showManager = false }) {
                        Image(systemName: "xmark")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Snippets list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(snippetManager.snippets) { snippet in
                            SnippetRow(snippet: snippet)
                                .onTapGesture {
                                    selectedSnippet = snippet
                                    showingEditor = true
                                }
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 600, height: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
            .shadow(radius: 20)

            if showingEditor {
                SnippetEditorView(
                    snippet: selectedSnippet,
                    isPresented: $showingEditor
                )
                .environmentObject(snippetManager)
            }
        }
    }
}

struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snippet.name)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(snippet.category)
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }

            Text(snippet.command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct SnippetEditorView: View {
    @EnvironmentObject var snippetManager: SnippetManager
    @Binding var isPresented: Bool

    @State private var name: String
    @State private var command: String
    @State private var category: String

    let snippet: Snippet?

    init(snippet: Snippet?, isPresented: Binding<Bool>) {
        self.snippet = snippet
        self._isPresented = isPresented
        self._name = State(initialValue: snippet?.name ?? "")
        self._command = State(initialValue: snippet?.command ?? "")
        self._category = State(initialValue: snippet?.category ?? "General")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                Text(snippet == nil ? "New Snippet" : "Edit Snippet")
                    .font(.headline)

                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Category", text: $category)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextEditor(text: $command)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 150)
                    .border(Color.gray.opacity(0.3))

                Text("Use {{VAR_NAME}} for variables")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Save") {
                        saveSnippet()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
        }
    }

    private func saveSnippet() {
        let variables = extractVariables(from: command)

        if let existing = snippet {
            let updated = Snippet(
                id: existing.id,
                name: name,
                command: command,
                variables: variables,
                category: category
            )
            snippetManager.updateSnippet(updated)
        } else {
            let new = Snippet(
                name: name,
                command: command,
                variables: variables,
                category: category
            )
            snippetManager.addSnippet(new)
        }

        isPresented = false
    }

    private func extractVariables(from command: String) -> [String] {
        let pattern = "\\{\\{([A-Z_]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(command.startIndex..., in: command)
        let matches = regex.matches(in: command, range: range)

        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: command) {
                return String(command[range])
            }
            return nil
        }
    }
}
