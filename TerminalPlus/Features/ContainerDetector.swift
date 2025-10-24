import Foundation
import Combine

class ContainerDetector: ObservableObject {
    @Published var isInContainer: Bool = false
    @Published var containerName: String?
    @Published var containerType: ContainerType = .none

    enum ContainerType {
        case none
        case docker
        case kubernetes
        case virtualMachine
    }

    private var timer: Timer?

    func startDetection() {
        detectContainer()

        // Check every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.detectContainer()
        }
    }

    func stopDetection() {
        timer?.invalidate()
        timer = nil
    }

    private func detectContainer() {
        // Check for Docker
        if isRunningInDocker() {
            DispatchQueue.main.async {
                self.isInContainer = true
                self.containerType = .docker
                self.containerName = self.getDockerContainerName()
            }
            return
        }

        // Check for Kubernetes
        if isRunningInKubernetes() {
            DispatchQueue.main.async {
                self.isInContainer = true
                self.containerType = .kubernetes
                self.containerName = self.getKubernetesPodName()
            }
            return
        }

        // Check for general containerization
        if isRunningInGeneralContainer() {
            DispatchQueue.main.async {
                self.isInContainer = true
                self.containerType = .virtualMachine
                self.containerName = "Container"
            }
            return
        }

        DispatchQueue.main.async {
            self.isInContainer = false
            self.containerType = .none
            self.containerName = nil
        }
    }

    private func isRunningInDocker() -> Bool {
        // Check for .dockerenv file
        if FileManager.default.fileExists(atPath: "/.dockerenv") {
            return true
        }

        // Check cgroup for docker
        if let cgroup = try? String(contentsOfFile: "/proc/1/cgroup", encoding: .utf8) {
            return cgroup.contains("docker")
        }

        return false
    }

    private func isRunningInKubernetes() -> Bool {
        // Check for Kubernetes service account
        if FileManager.default.fileExists(atPath: "/var/run/secrets/kubernetes.io") {
            return true
        }

        // Check environment variables
        if ProcessInfo.processInfo.environment["KUBERNETES_SERVICE_HOST"] != nil {
            return true
        }

        return false
    }

    private func isRunningInGeneralContainer() -> Bool {
        // Check cgroup
        if let cgroup = try? String(contentsOfFile: "/proc/1/cgroup", encoding: .utf8) {
            return cgroup.contains("lxc") || cgroup.contains("containerd")
        }

        return false
    }

    private func getDockerContainerName() -> String? {
        // Try to get hostname which is usually the container ID
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/hostname")

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let hostname = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return "Docker: \(hostname.prefix(12))"
            }
        } catch {
            return "Docker Container"
        }

        return "Docker Container"
    }

    private func getKubernetesPodName() -> String? {
        // Check HOSTNAME environment variable (usually set to pod name)
        if let podName = ProcessInfo.processInfo.environment["HOSTNAME"] {
            return "K8s: \(podName)"
        }

        return "Kubernetes Pod"
    }

    func getStatusIndicator() -> String {
        switch containerType {
        case .none:
            return ""
        case .docker:
            return "🐳 \(containerName ?? "Docker")"
        case .kubernetes:
            return "☸️ \(containerName ?? "K8s")"
        case .virtualMachine:
            return "📦 \(containerName ?? "Container")"
        }
    }
}
