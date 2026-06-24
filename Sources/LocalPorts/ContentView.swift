import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: ServerStore

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                tabBar
                Divider().overlay(Theme.stroke)
                list
                footer
            }
        }
        .frame(minWidth: 380, minHeight: 360)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(Theme.accentDim).frame(width: 24, height: 24)
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("LocalPort").font(.system(size: 13, weight: .semibold))
                Text(verbatim: "\(store.servers.count) listening")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            searchField

            Button(action: { store.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .help("Refresh now")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Tab strip

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                TabPill(
                    label: "All",
                    count: store.servers.count,
                    selected: store.selectedProcess == nil
                ) { store.selectedProcess = nil }

                ForEach(store.processGroups, id: \.name) { group in
                    TabPill(
                        label: Self.shortLabel(group.name),
                        count: group.count,
                        selected: store.selectedProcess == group.name
                    ) { store.selectedProcess = group.name }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    /// Compact tab label: "com.docker.backend" -> "docker", others kept short.
    static func shortLabel(_ name: String) -> String {
        if name.hasPrefix("com.") {
            let parts = name.dropFirst(4).split(separator: ".")
            if let first = parts.first { return String(first) }
        }
        return name
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Filter", text: $store.search)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(width: 90)
            if !store.search.isEmpty {
                Button(action: { store.search = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Theme.rowFill, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if store.filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(store.filtered) { entry in
                        ServerRow(entry: entry) { store.kill(entry) }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: store.search.isEmpty ? "moon.zzz" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(store.search.isEmpty ? "No servers listening" : "No matches")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
            Text("Live")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            if let updated = store.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.2))
    }
}

// MARK: - Row

private struct ServerRow: View {
    let entry: ServerEntry
    let onKill: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            // Process glyph chip
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.tint(for: entry.command).opacity(0.18))
                Text(initials)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.tint(for: entry.command))
            }
            .frame(width: 28, height: 28)

            // Port + process
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(verbatim: ":\(entry.port)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    if entry.isLoopbackOrAny {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5)
                            .help("Reachable on this machine")
                    }
                }
                Text(entry.command)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Meta + actions
            if hovering {
                actionButtons
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(addressLabel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(verbatim: "PID \(entry.pid)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(hovering ? Theme.rowHover : Theme.rowFill,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { open() }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if entry.url != nil {
                Button(action: open) {
                    Label("Open", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(PillButtonStyle(tint: Theme.accent))
            }
            Button(action: onKill) {
                Image(systemName: "stop.fill").font(.system(size: 10))
            }
            .buttonStyle(PillButtonStyle(tint: Color(red: 1, green: 0.42, blue: 0.42)))
            .help("Quit this process (SIGTERM)")
        }
    }

    private var initials: String {
        let cleaned = entry.command
            .replacingOccurrences(of: "com.", with: "")
            .replacingOccurrences(of: ".", with: " ")
        return String(cleaned.prefix(2)).uppercased()
    }

    private var addressLabel: String {
        switch entry.address {
        case "", "*": return "all"
        case "127.0.0.1", "::1": return "localhost"
        default: return entry.address
        }
    }

    private func open() {
        if let url = entry.url { NSWorkspace.shared.open(url) }
    }
}

// MARK: - Tab pill

private struct TabPill: View {
    let label: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                Text(verbatim: "\(count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        (selected ? Theme.accent.opacity(0.18) : Color.white.opacity(0.08)),
                        in: Capsule()
                    )
            }
            .foregroundStyle(selected ? .primary : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                selected ? Theme.accentDim : Theme.rowFill,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(selected ? Theme.accent.opacity(0.5) : Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

// MARK: - Button styles

private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(configuration.isPressed ? Theme.rowHover : Theme.rowFill,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}

private struct PillButtonStyle: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(configuration.isPressed ? 0.28 : 0.16),
                        in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
    }
}
