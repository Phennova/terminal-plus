# Terminal Plus

A modern, feature-rich terminal application for Apple Silicon Macs with advanced productivity features and beautiful UI enhancements.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-green)

## Features

### Visual & UX Improvements

- **Intelligent Color Coding**: Advanced syntax highlighting and semantic coloring for different terminal elements
- **Inline File Previews**: Hover over file paths to see thumbnail previews for images, PDFs, and text files
- **Visual Git Integration**: Real-time branch status, uncommitted changes, and merge conflict indicators in the status bar
- **Split Panes**: Arrange multiple terminal sessions with drag-and-drop functionality
  - Split horizontally (Cmd+Shift+D)
  - Split vertically (Cmd+D)
  - Resize panes dynamically

### Productivity Features

- **Command Palette** (Cmd+Shift+P): Searchable list of:
  - Common terminal tasks
  - Saved snippets
  - Recent commands
  - Frequent directories

- **Snippet Manager** (Cmd+Shift+S):
  - Save frequently used commands
  - Support for variables with `{{VAR_NAME}}` syntax
  - Organize snippets by category
  - Quick access through Command Palette

- **Time-Travel Debugger** (Cmd+Shift+H):
  - Replay command history with full output
  - Search through historical commands
  - View commands by directory
  - No need to re-execute commands

- **Smart Directory Jumping**:
  - Type `j <partial-name>` to jump to frequently visited directories
  - Learns from your navigation patterns
  - Fuzzy matching support

### Modern Development Tools

- **Integrated Package Manager UI** (Cmd+Shift+B):
  - Visual interface for Homebrew
  - View installed packages
  - Check for updates
  - Install/uninstall packages with one click

- **Container Awareness**:
  - Automatic detection of Docker containers
  - Kubernetes pod indicators
  - Visual cues when inside virtual environments

- **Environment Variable Manager** (Cmd+Shift+E):
  - GUI for viewing all environment variables
  - Easy editing without touching config files
  - Import/export variable sets
  - Automatic persistence to shell profile

## System Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (M1, M2, M3, or later)
- **Xcode**: 15.0 or later (for building)
- **Optional**: Homebrew (for package manager features)

## Building from Source

### Prerequisites

1. **Install Xcode**:
   ```bash
   # Install from the Mac App Store or download from:
   # https://developer.apple.com/xcode/

   # Verify installation
   xcode-select --version
   ```

2. **Install Command Line Tools** (if not already installed):
   ```bash
   xcode-select --install
   ```

### Build Instructions

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/terminal-plus.git
   cd terminal-plus
   ```

2. **Open in Xcode**:
   ```bash
   open TerminalPlus.xcodeproj
   ```

3. **Configure Signing** (in Xcode):
   - Select the project in the navigator
   - Select "TerminalPlus" target
   - Go to "Signing & Capabilities" tab
   - Select your development team
   - Xcode will automatically manage signing

4. **Build the application**:

   **Option A: Using Xcode**
   - Select "Product" → "Build" (Cmd+B)
   - Or select "Product" → "Run" (Cmd+R) to build and run

   **Option B: Using Command Line**
   ```bash
   # Build for Apple Silicon
   xcodebuild -project TerminalPlus.xcodeproj \
              -scheme TerminalPlus \
              -configuration Release \
              -arch arm64 \
              build

   # The built app will be in:
   # build/Release/TerminalPlus.app
   ```

5. **Create a distributable build**:
   ```bash
   # Archive the application
   xcodebuild -project TerminalPlus.xcodeproj \
              -scheme TerminalPlus \
              -configuration Release \
              -arch arm64 \
              archive \
              -archivePath build/TerminalPlus.xcarchive

   # Export the app
   xcodebuild -exportArchive \
              -archivePath build/TerminalPlus.xcarchive \
              -exportPath build/Release \
              -exportOptionsPlist exportOptions.plist
   ```

### Installation

1. **Install to Applications folder**:
   ```bash
   # After building
   cp -R build/Release/TerminalPlus.app /Applications/
   ```

2. **First Launch**:
   - Open Terminal Plus from Applications
   - You may need to allow the app in System Settings → Privacy & Security
   - Grant Terminal access when prompted

## Usage Guide

### Getting Started

1. **Launch Terminal Plus** from Applications or Spotlight
2. A new terminal session will open automatically
3. Your default shell (zsh, bash, etc.) will be loaded

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New terminal tab |
| `Cmd+D` | Split pane vertically |
| `Cmd+Shift+D` | Split pane horizontally |
| `Cmd+Shift+P` | Open Command Palette |
| `Cmd+Shift+S` | Open Snippet Manager |
| `Cmd+Shift+E` | Open Environment Manager |
| `Cmd+Shift+B` | Open Package Manager |
| `Cmd+Shift+H` | Open Time-Travel Debugger |
| `Cmd+K` | Clear terminal |
| `Cmd+,` | Open Settings |

### Using Features

#### Creating Snippets

1. Press `Cmd+Shift+S` to open Snippet Manager
2. Click the "+" button
3. Enter:
   - Name: Description of the snippet
   - Category: Organize your snippets
   - Command: The actual command with `{{VARIABLES}}`
4. Click "Save"

**Example Snippet**:
```
Name: SSH to Server
Category: Network
Command: ssh {{USER}}@{{HOST}}
```

When you use this snippet, you'll be prompted to fill in USER and HOST.

#### Smart Directory Jumping

Instead of typing full paths:
```bash
# Traditional way
cd ~/Documents/Projects/terminal-plus/src

# With Terminal Plus
j terminal
# Automatically jumps to most frequently accessed matching directory
```

#### Time-Travel Debugging

1. Run some commands in your terminal
2. Press `Cmd+Shift+H` to open the debugger
3. Browse through your command history
4. Click any command to see:
   - Full output (without re-running)
   - Exit code
   - Working directory
   - Timestamp

#### File Previews

Simply hover over any file path in the terminal output:
```bash
ls ~/Pictures/*.jpg
# Hover over any .jpg path to see a thumbnail preview
```

Supports:
- Images (PNG, JPG, GIF, etc.)
- PDFs (first page preview)
- Text files (first 500 characters)
- JSON files (formatted)

#### Container Detection

Terminal Plus automatically detects when you're inside:
- Docker containers (shows container ID)
- Kubernetes pods (shows pod name)
- Other virtualized environments

The status bar will display the container info with an icon.

### Customization

Access settings via `Cmd+,`:

- **Color Schemes**: Dark, Light, Solarized Dark, Solarized Light
- **Font**: Choose from Menlo, Monaco, SF Mono, Courier New
- **Font Size**: 10-24pt
- **Cursor**: Toggle blinking

## Project Structure

```
terminal-plus/
├── TerminalPlus.xcodeproj/      # Xcode project file
├── TerminalPlus/
│   ├── Sources/                 # Core application files
│   │   ├── TerminalPlusApp.swift    # App entry point
│   │   ├── ContentView.swift        # Main UI
│   │   ├── TerminalView.swift       # Terminal display
│   │   ├── PTYController.swift      # Pseudo-terminal management
│   │   ├── TerminalEmulator.swift   # VT100/ANSI processing
│   │   └── ColorScheme.swift        # Color themes
│   ├── Features/                # Feature implementations
│   │   ├── CommandPalette.swift
│   │   ├── SnippetManager.swift
│   │   ├── GitIntegration.swift
│   │   ├── SplitPaneManager.swift
│   │   ├── PreviewManager.swift
│   │   ├── TimeTravelDebugger.swift
│   │   ├── DirectoryJumper.swift
│   │   ├── PackageManagerUI.swift
│   │   ├── ContainerDetector.swift
│   │   └── EnvironmentManager.swift
│   ├── Resources/               # App resources
│   │   └── Assets.xcassets/
│   └── Supporting Files/        # Configuration files
│       ├── Info.plist
│       └── TerminalPlus.entitlements
└── README.md                    # This file
```

## Architecture

Terminal Plus is built using:

- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for state management
- **PTY (Pseudo-Terminal)**: Low-level terminal emulation using Darwin APIs
- **VT100/ANSI**: Full support for escape sequences and terminal control codes
- **AppKit**: Native macOS integration

### Key Components

1. **PTYController**: Manages the pseudo-terminal device, forks shell processes, and handles I/O
2. **TerminalEmulator**: Processes VT100/ANSI escape sequences and maintains the terminal buffer
3. **TerminalView**: Renders the terminal content using custom NSView
4. **Feature Managers**: Independent modules for each major feature (snippets, git, packages, etc.)

## Development

### Adding New Features

1. Create a new Swift file in `TerminalPlus/Features/`
2. Implement as an `ObservableObject` for reactive state
3. Add to `TerminalPlusApp.swift` as an `@StateObject`
4. Inject via `.environmentObject()` in the view hierarchy
5. Add keyboard shortcuts or menu items as needed

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on Apple Silicon
5. Submit a pull request

## Troubleshooting

### App won't launch
- Check System Settings → Privacy & Security
- Ensure you've granted necessary permissions
- Try running from terminal: `open /Applications/TerminalPlus.app`

### Build errors
- Ensure Xcode is up to date (15.0+)
- Clean build folder: `Cmd+Shift+K` in Xcode
- Check that you're building for arm64 architecture

### Shell doesn't start
- Verify your default shell: `echo $SHELL`
- Check shell exists: `which zsh` or `which bash`
- Review entitlements in project settings

### Homebrew features not working
- Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- Verify brew is in PATH: `which brew`
- Common location: `/opt/homebrew/bin/brew` (Apple Silicon)

## Technical Details

### Terminal Emulation

Terminal Plus implements a full VT100/ANSI terminal emulator with support for:

- **Cursor Movement**: All standard cursor positioning commands
- **Text Attributes**: Bold, italic, underline
- **Colors**: 8-color, 16-color, and 256-color modes
- **Screen Control**: Clear, scroll, line wrapping
- **Special Sequences**: OSC, CSI, and control characters

### Performance

- **Buffer Management**: Efficient scrollback with configurable limit (default: 10,000 lines)
- **Rendering**: Optimized NSView rendering with dirty region tracking
- **I/O**: Non-blocking PTY operations on background queue
- **Memory**: Automatic cleanup of old history entries

## License

Copyright © 2025. All rights reserved.

## Credits

Built with:
- Swift and SwiftUI
- macOS AppKit
- Darwin PTY APIs

## Support

For issues, feature requests, or questions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the documentation

---

**Terminal Plus** - A modern terminal for modern developers.
