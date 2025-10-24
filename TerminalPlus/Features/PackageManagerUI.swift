import Foundation
import SwiftUI

struct BrewPackage: Identifiable, Codable {
    let id = UUID()
    let name: String
    let version: String
    let description: String
    var isInstalled: Bool
    var isOutdated: Bool
}

class PackageManagerUI: ObservableObject {
    @Published var installedPackages: [BrewPackage] = []
    @Published var availablePackages: [BrewPackage] = []
    @Published var outdatedPackages: [BrewPackage] = []
    @Published var showManager: Bool = false
    @Published var isLoading: Bool = false
    @Published var hasHomebrew: Bool = false

    init() {
        checkHomebrewInstallation()
    }

    func checkHomebrewInstallation() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["brew"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            hasHomebrew = process.terminationStatus == 0
            if hasHomebrew {
                refreshPackages()
            }
        } catch {
            hasHomebrew = false
        }
    }

    func refreshPackages() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadInstalledPackages()
            self?.loadOutdatedPackages()

            DispatchQueue.main.async {
                self?.isLoading = false
            }
        }
    }

    private func loadInstalledPackages() {
        let output = executeBrewCommand(["list", "--versions"])
        let lines = output.split(separator: "\n")

        var packages: [BrewPackage] = []

        for line in lines {
            let components = line.split(separator: " ", maxSplits: 1)
            if components.count >= 2 {
                let name = String(components[0])
                let version = String(components[1])

                packages.append(BrewPackage(
                    name: name,
                    version: version,
                    description: getPackageDescription(name),
                    isInstalled: true,
                    isOutdated: false
                ))
            }
        }

        DispatchQueue.main.async {
            self.installedPackages = packages
        }
    }

    private func loadOutdatedPackages() {
        let output = executeBrewCommand(["outdated", "--verbose"])
        let lines = output.split(separator: "\n")

        var packages: [BrewPackage] = []

        for line in lines {
            let components = line.split(separator: " ")
            if components.count >= 1 {
                let name = String(components[0])

                packages.append(BrewPackage(
                    name: name,
                    version: "outdated",
                    description: getPackageDescription(name),
                    isInstalled: true,
                    isOutdated: true
                ))
            }
        }

        DispatchQueue.main.async {
            self.outdatedPackages = packages
        }
    }

    private func getPackageDescription(_ packageName: String) -> String {
        let output = executeBrewCommand(["info", packageName, "--json=v2"])

        if let data = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let formulae = json["formulae"] as? [[String: Any]],
           let first = formulae.first,
           let description = first["desc"] as? String {
            return description
        }

        return ""
    }

    func installPackage(_ packageName: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.executeBrewCommand(["install", packageName])
            let success = !output.contains("Error")

            DispatchQueue.main.async {
                if success {
                    self.refreshPackages()
                }
                completion(success)
            }
        }
    }

    func uninstallPackage(_ packageName: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.executeBrewCommand(["uninstall", packageName])
            let success = !output.contains("Error")

            DispatchQueue.main.async {
                if success {
                    self.refreshPackages()
                }
                completion(success)
            }
        }
    }

    func upgradePackage(_ packageName: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.executeBrewCommand(["upgrade", packageName])
            let success = !output.contains("Error")

            DispatchQueue.main.async {
                if success {
                    self.refreshPackages()
                }
                completion(success)
            }
        }
    }

    func upgradeAll(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.executeBrewCommand(["upgrade"])
            let success = !output.contains("Error")

            DispatchQueue.main.async {
                if success {
                    self.refreshPackages()
                }
                completion(success)
            }
        }
    }

    private func executeBrewCommand(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

struct PackageManagerView: View {
    @EnvironmentObject var packageManager: PackageManagerUI
    @State private var selectedTab = 0
    @State private var searchText = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    packageManager.showManager = false
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Homebrew Package Manager")
                        .font(.headline)
                    Spacer()
                    Button(action: { packageManager.refreshPackages() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(packageManager.isLoading)
                    Button(action: { packageManager.showManager = false }) {
                        Image(systemName: "xmark")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                if !packageManager.hasHomebrew {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Homebrew is not installed")
                            .font(.headline)
                        Text("Install Homebrew from https://brew.sh")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Tabs
                    Picker("", selection: $selectedTab) {
                        Text("Installed (\(packageManager.installedPackages.count))").tag(0)
                        Text("Outdated (\(packageManager.outdatedPackages.count))").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search packages...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal)

                    Divider()

                    // Package list
                    if packageManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(filteredPackages) { package in
                                    PackageRow(package: package)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .frame(width: 700, height: 600)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(10)
            .shadow(radius: 20)
        }
    }

    private var filteredPackages: [BrewPackage] {
        let packages = selectedTab == 0 ? packageManager.installedPackages : packageManager.outdatedPackages

        if searchText.isEmpty {
            return packages
        }

        return packages.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct PackageRow: View {
    @EnvironmentObject var packageManager: PackageManagerUI
    let package: BrewPackage
    @State private var isProcessing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(package.name)
                    .font(.system(size: 14, weight: .medium))

                Text(package.description)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)

                Text(package.version)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.blue)
            }

            Spacer()

            if isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                if package.isOutdated {
                    Button("Upgrade") {
                        upgradePackage()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(package.isInstalled ? "Uninstall" : "Install") {
                    if package.isInstalled {
                        uninstallPackage()
                    } else {
                        installPackage()
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private func installPackage() {
        isProcessing = true
        packageManager.installPackage(package.name) { _ in
            isProcessing = false
        }
    }

    private func uninstallPackage() {
        isProcessing = true
        packageManager.uninstallPackage(package.name) { _ in
            isProcessing = false
        }
    }

    private func upgradePackage() {
        isProcessing = true
        packageManager.upgradePackage(package.name) { _ in
            isProcessing = false
        }
    }
}
