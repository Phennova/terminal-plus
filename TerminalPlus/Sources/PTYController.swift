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
        var flags = fcntl(masterFD, F_GETFL, 0)
        flags |= O_NONBLOCK
        fcntl(masterFD, F_SETFL, flags)

        // Fork process
        let pid = fork()

        if pid == -1 {
            print("Failed to fork: \(String(cString: strerror(errno)))")
            return
        } else if pid == 0 {
            // Child process
            close(masterFD)

            // Create new session
            setsid()

            // Set slave as controlling terminal
            if ioctl(slaveFD, TIOCSCTTY, nil) == -1 {
                exit(1)
            }

            // Redirect stdin, stdout, stderr to slave
            dup2(slaveFD, STDIN_FILENO)
            dup2(slaveFD, STDOUT_FILENO)
            dup2(slaveFD, STDERR_FILENO)

            // Close original slave FD
            if slaveFD > STDERR_FILENO {
                close(slaveFD)
            }

            // Set environment variables
            setenv("TERM", "xterm-256color", 1)
            setenv("COLORTERM", "truecolor", 1)
            setenv("TERM_PROGRAM", "TerminalPlus", 1)

            // Get user's shell
            let shell = getenv("SHELL").flatMap { String(cString: $0) } ?? "/bin/zsh"
            let shellName = (shell as NSString).lastPathComponent

            // Execute shell
            execl(shell, shellName, "-l", nil)
            exit(1)
        } else {
            // Parent process
            close(slaveFD)
            childPID = pid

            // Setup read source for output
            setupReadSource()
        }
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
        data.withCString { ptr in
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

        ioctl(masterFD, TIOCSWINSZ, &size)
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
