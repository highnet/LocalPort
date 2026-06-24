# LocalPort

A slick little macOS app that tracks every server you're running locally. It lists
all listening TCP ports, shows which process owns each one, and lets you open them
in the browser or stop them, right from a window or the menu bar.

## Features

- Live list of every listening TCP port (refreshes every few seconds)
- Owning process name + PID for each port
- Dynamic tabs that group ports by process (node, docker, etc.), built on the fly
- One click to open `http://localhost:PORT` in your browser
- One click to stop a process (SIGTERM)
- Menu bar (tray) icon with a quick dropdown of active ports
- Filter by port, process, or address
- Single-window, runs quietly in the menu bar
- Native SwiftUI, no dependencies

## How it works

It shells out to `lsof -nP -iTCP -sTCP:LISTEN` in machine-readable mode and parses
the result. No special permissions are needed to see your own processes.

## Build

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16+).

```bash
# Run straight from source
swift run

# Build LocalPort.app (with icon) into the project folder
./make-app.sh

# Build and install into /Applications
./make-app.sh --install
```

## Project layout

| File | Purpose |
|------|---------|
| `Sources/LocalPorts/PortScanner.swift` | Runs and parses `lsof` |
| `Sources/LocalPorts/ServerStore.swift` | Observable model, timer-based polling |
| `Sources/LocalPorts/ContentView.swift` | Main window UI |
| `Sources/LocalPorts/MenuBarView.swift` | Menu bar dropdown |
| `Sources/LocalPorts/Theme.swift` | Colors and styling |
| `make-icon.swift` | Generates the app icon |
| `make-app.sh` | Assembles and installs the `.app` bundle |

## License

MIT, see [LICENSE](LICENSE).
