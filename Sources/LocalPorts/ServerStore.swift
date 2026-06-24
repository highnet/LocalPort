import Foundation
import SwiftUI

/// Observable model that polls for listening servers on a timer.
@MainActor
final class ServerStore: ObservableObject {
    @Published private(set) var servers: [ServerEntry] = []
    @Published private(set) var lastUpdated: Date?
    @Published var search: String = ""
    /// nil = the "All" tab; otherwise a process name to narrow to.
    @Published var selectedProcess: String? = nil

    /// Seconds between automatic scans.
    let interval: TimeInterval = 3

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var filtered: [ServerEntry] {
        var result = servers
        if let process = selectedProcess {
            result = result.filter { $0.command == process }
        }
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.command.lowercased().contains(query)
                    || String($0.port).contains(query)
                    || $0.address.lowercased().contains(query)
            }
        }
        return result
    }

    /// Distinct processes with their port counts, for the tab strip.
    /// Sorted by count (desc) then name, so the busiest servers lead.
    var processGroups: [(name: String, count: Int)] {
        Dictionary(grouping: servers, by: \.command)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    func refresh() {
        Task.detached(priority: .userInitiated) {
            let scanned = PortScanner.scan()
            await MainActor.run {
                self.servers = scanned
                self.lastUpdated = Date()
                // Drop the tab selection if that process is no longer listening.
                if let selected = self.selectedProcess,
                   !scanned.contains(where: { $0.command == selected }) {
                    self.selectedProcess = nil
                }
            }
        }
    }

    func kill(_ entry: ServerEntry) {
        PortScanner.kill(pid: entry.pid)
        // Give the process a beat to release the socket, then rescan.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }

}
