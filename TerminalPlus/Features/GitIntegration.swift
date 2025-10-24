import Foundation
import Combine

class GitIntegration: ObservableObject {
    @Published var currentBranch: String?
    @Published var hasUncommittedChanges: Bool = false
    @Published var ahead: Int = 0
    @Published var behind: Int = 0
    @Published var conflictFiles: [String] = []

    private var monitoringDirectory: String?
    private var timer: Timer?

    func startMonitoring(directory: String) {
        monitoringDirectory = directory
        updateGitStatus()

        // Poll for changes every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateGitStatus()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        monitoringDirectory = nil
    }

    private func updateGitStatus() {
        guard let directory = monitoringDirectory else { return }

        // Get current branch
        if let branch = executeGitCommand(["branch", "--show-current"], in: directory) {
            DispatchQueue.main.async {
                self.currentBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Check for uncommitted changes
        if let status = executeGitCommand(["status", "--porcelain"], in: directory) {
            DispatchQueue.main.async {
                self.hasUncommittedChanges = !status.isEmpty
            }
        }

        // Check ahead/behind
        if let revList = executeGitCommand(["rev-list", "--left-right", "--count", "HEAD...@{u}"], in: directory) {
            let components = revList.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
            if components.count == 2 {
                DispatchQueue.main.async {
                    self.ahead = Int(components[0]) ?? 0
                    self.behind = Int(components[1]) ?? 0
                }
            }
        }

        // Check for conflicts
        if let diff = executeGitCommand(["diff", "--name-only", "--diff-filter=U"], in: directory) {
            let conflicts = diff.split(separator: "\n").map { String($0) }
            DispatchQueue.main.async {
                self.conflictFiles = conflicts
            }
        }
    }

    private func executeGitCommand(_ arguments: [String], in directory: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func getGitStatusIndicator() -> String {
        var indicator = ""

        if let branch = currentBranch {
            indicator += branch
        }

        if hasUncommittedChanges {
            indicator += " *"
        }

        if ahead > 0 {
            indicator += " ↑\(ahead)"
        }

        if behind > 0 {
            indicator += " ↓\(behind)"
        }

        if !conflictFiles.isEmpty {
            indicator += " ⚠️"
        }

        return indicator
    }
}
