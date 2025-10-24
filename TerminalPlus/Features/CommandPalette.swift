import SwiftUI

struct CommandPaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let action: () -> Void
}

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @EnvironmentObject var snippetManager: SnippetManager
    @EnvironmentObject var directoryJumper: DirectoryJumper

    private var commands: [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []

        // Built-in commands
        items.append(CommandPaletteItem(
            title: "New Terminal Tab",
            subtitle: "⌘T",
            icon: "plus.square",
            action: {
                NotificationCenter.default.post(name: NSNotification.Name("NewTerminalTab"), object: nil)
            }
        ))

        items.append(CommandPaletteItem(
            title: "Split Pane Horizontally",
            subtitle: "⌘⇧D",
            icon: "rectangle.split.2x1",
            action: {
                NotificationCenter.default.post(name: NSNotification.Name("SplitHorizontally"), object: nil)
            }
        ))

        items.append(CommandPaletteItem(
            title: "Split Pane Vertically",
            subtitle: "⌘D",
            icon: "rectangle.split.1x2",
            action: {
                NotificationCenter.default.post(name: NSNotification.Name("SplitVertically"), object: nil)
            }
        ))

        items.append(CommandPaletteItem(
            title: "Clear Terminal",
            subtitle: "⌘K",
            icon: "trash",
            action: {
                NotificationCenter.default.post(name: NSNotification.Name("ClearTerminal"), object: nil)
            }
        ))

        // Snippet commands
        for snippet in snippetManager.snippets {
            items.append(CommandPaletteItem(
                title: "Snippet: \(snippet.name)",
                subtitle: snippet.command,
                icon: "doc.text",
                action: {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("InsertSnippet"),
                        object: snippet.command
                    )
                }
            ))
        }

        // Recent directories
        for directory in directoryJumper.recentDirectories.prefix(5) {
            items.append(CommandPaletteItem(
                title: "Jump to: \(directory.name)",
                subtitle: directory.path,
                icon: "folder",
                action: {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("JumpToDirectory"),
                        object: directory.path
                    )
                }
            ))
        }

        return items
    }

    private var filteredCommands: [CommandPaletteItem] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Type a command...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Commands list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            CommandRow(
                                command: command,
                                isSelected: index == selectedIndex
                            )
                            .onTapGesture {
                                command.action()
                                isPresented = false
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
            .frame(width: 600)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
            .shadow(radius: 20)
        }
        .onAppear {
            selectedIndex = 0
        }
    }
}

struct CommandRow: View {
    let command: CommandPaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 14, weight: .medium))

                if let subtitle = command.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}
