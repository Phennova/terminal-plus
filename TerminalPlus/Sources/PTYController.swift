import Foundation
import Darwin

class PTYController: ObservableObject {
    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    private var childPID: pid_t = -1
    private var readSource: DispatchSourceRead?
    @Published var currentDirectory: String = FileManager.default.currentDirectoryPath

    var onOutput: ((Data) -> Void)?

    func start() {
        // Create pseudo-terminal
        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0

        if openpty(&masterFD, &slaveFD, nil, nil, nil) == -1 {
            print("Failed to create PTY: \(String(cString: strerror(errno)))")
            return
        }

        self.masterFD = masterFD
        self.slaveFD = slaveFD

        // Set non-blocking mode
        let flags = fcntl(masterFD, F_GETFL, 0)
        if flags == -1 {
            print("Failed to get flags: \(String(cString: strerror(errno)))")
            return
        }

        if fcntl(masterFD, F_SETFL, flags | O_NONBLOCK) == -1 {
            print("Failed to set non-blocking: \(String(cString: strerror(errno)))")
            return
        }

        // Get slave path
        var nameBuf = [CChar](repeating: 0, count: 1024)
        if ttyname_r(slaveFD, &nameBuf, nameBuf.count) != 0 {
            print("Failed to get slave name")
            return
        }

        let slavePath = String(cString: nameBuf)

        // Prepare file actions for posix_spawn
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)

        // Setup stdin, stdout, stderr to use slave
        posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDERR_FILENO)

        // Close the slave in child after dup2
        if slaveFD > STDERR_FILENO {
            posix_spawn_file_actions_addclose(&fileActions, slaveFD)
        }

        // Close master in child
        posix_spawn_file_actions_addclose(&fileActions, masterFD)

        // Setup spawn attributes
        var spawnAttrs: posix_spawnattr_t?
        posix_spawnattr_init(&spawnAttrs)

        // Set flags for process group
        var spawnFlags: Int16 = 0
        #if os(macOS)
        spawnFlags = Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK)
        #endif
        posix_spawnattr_setflags(&spawnAttrs, spawnFlags)

        // Get user's shell
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = (shell as NSString).lastPathComponent

        // Setup environment
        var env = [
            "TERM=xterm-256color",
            "COLORTERM=truecolor",
            "TERM_PROGRAM=TerminalPlus",
            "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        ]

        // Add existing environment variables
        for (key, value) in ProcessInfo.processInfo.environment {
            if !["TERM", "COLORTERM", "TERM_PROGRAM"].contains(key) {
                env.append("\(key)=\(value)")
            }
        }

        let envp = env.map { $0.withCString(strdup) } + [nil]
        defer { envp.forEach { free($0) } }

        // Arguments for shell
        let argv = [
            strdup(shell),
            strdup("-l"),
            nil
        ]
        defer { argv.forEach { free($0) } }

        // Spawn process
        var pid: pid_t = 0
        let result = posix_spawn(&pid, shell, &fileActions, &spawnAttrs, argv, envp)

        // Cleanup
        posix_spawn_file_actions_destroy(&fileActions)
        posix_spawnattr_destroy(&spawnAttrs)

        if result != 0 {
            print("Failed to spawn shell: \(String(cString: strerror(result)))")
            close(masterFD)
            close(slaveFD)
            return
        }

        // Close slave in parent
        close(slaveFD)
        self.slaveFD = -1

        self.childPID = pid

        // Setup read source for output
        setupReadSource()
    }

    private func setupReadSource() {
        readSource = DispatchSource.makeReadSource(fileDescriptor: masterFD, queue: .global())

        readSource?.setEventHandler { [weak self] in
            guard let self = self else { return }

            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(self.masterFD, &buffer, buffer.count)

            if bytesRead > 0 {
                let data = Data(buffer[0..<bytesRead])
                DispatchQueue.main.async {
                    self.onOutput?(data)
                }
            }
        }

        readSource?.setCancelHandler { [weak self] in
            if let masterFD = self?.masterFD, masterFD >= 0 {
                close(masterFD)
            }
        }

        readSource?.resume()
    }

    func write(_ data: String) {
        guard masterFD >= 0 else { return }
        _ = data.withCString { ptr in
            Darwin.write(masterFD, ptr, strlen(ptr))
        }
    }

    func resize(width: Int, height: Int) {
        guard masterFD >= 0 else { return }

        var size = winsize()
        size.ws_col = UInt16(width)
        size.ws_row = UInt16(height)
        size.ws_xpixel = 0
        size.ws_ypixel = 0

        _ = ioctl(masterFD, TIOCSWINSZ, &size)
    }

    func stop() {
        readSource?.cancel()
        readSource = nil

        if childPID > 0 {
            kill(childPID, SIGTERM)

            var status: Int32 = 0
            waitpid(childPID, &status, 0)
            childPID = -1
        }

        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
    }

    deinit {
        stop()
    }
}
