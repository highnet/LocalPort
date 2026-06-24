import Foundation

/// Enumerates listening TCP ports by shelling out to `lsof` in field-output mode.
enum PortScanner {

    /// Runs lsof and returns the current set of listening servers.
    static func scan() -> [ServerEntry] {
        // -nP: no DNS / port-name resolution (fast, numeric).
        // -iTCP -sTCP:LISTEN: only TCP sockets in LISTEN state.
        // -F pcPn: machine-readable field output (pid, command, proto, name).
        guard let raw = run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcPn"]) else {
            return []
        }
        return parse(raw)
    }

    /// Sends SIGTERM to a process. Returns true if the signal was dispatched.
    @discardableResult
    static func kill(pid: Int32) -> Bool {
        Foundation.kill(pid, SIGTERM) == 0
    }

    // MARK: - Parsing

    /// Parses lsof `-F pcPn` output. Fields are one-per-line, each prefixed by a
    /// type char. Process records (p, c) precede their file records (P, n).
    static func parse(_ text: String) -> [ServerEntry] {
        var entries: [ServerEntry] = []
        var seen = Set<String>()

        var pid: Int32 = 0
        var command = ""
        var proto = "TCP"

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())

            switch tag {
            case "p":
                pid = Int32(value) ?? 0
            case "c":
                command = value
            case "P":
                proto = value
            case "n":
                // e.g. "*:7000", "127.0.0.1:5432", "[::1]:631"
                guard let (address, port) = splitAddress(value) else { continue }
                let entry = ServerEntry(
                    pid: pid, command: command, port: port, address: address, proto: proto
                )
                if seen.insert(entry.id).inserted {
                    entries.append(entry)
                }
            default:
                break
            }
        }

        return entries.sorted { $0.port < $1.port }
    }

    /// Splits "host:port" handling IPv6 brackets. Returns nil if no numeric port.
    private static func splitAddress(_ name: String) -> (address: String, port: Int)? {
        guard let colon = name.lastIndex(of: ":") else { return nil }
        let portStr = name[name.index(after: colon)...]
        guard let port = Int(portStr) else { return nil }
        var address = String(name[..<colon])
        address = address.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return (address, port)
    }

    // MARK: - Process helpers

    private static func run(_ path: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
