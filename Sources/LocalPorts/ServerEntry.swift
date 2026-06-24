import Foundation

/// One listening server: a process bound to a localhost/all-interfaces TCP port.
struct ServerEntry: Identifiable, Hashable {
    let pid: Int32
    let command: String        // short process name, e.g. "node"
    let port: Int
    let address: String        // bind address, e.g. "127.0.0.1", "*", "::1"
    let proto: String          // "TCP"

    /// Stable identity across refreshes: a given process owns a given port.
    var id: String { "\(pid)-\(proto)-\(port)" }

    /// Whether this looks reachable from a browser on this machine.
    var isLoopbackOrAny: Bool {
        address == "*" || address == "127.0.0.1" || address == "::1" || address.isEmpty
    }

    var url: URL? {
        guard isLoopbackOrAny else { return nil }
        return URL(string: "http://localhost:\(port)")
    }
}
