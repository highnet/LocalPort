import SwiftUI
import AppKit

/// The dropdown shown when clicking the menu bar (tray) icon.
struct MenuBarView: View {
    @ObservedObject var store: ServerStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "\(store.servers.count) listening")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: { store.refresh() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if store.servers.isEmpty {
                Text("No servers running")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.servers) { entry in
                            MenuRow(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            Divider()

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open LocalPort", systemImage: "macwindow")
            }
            .buttonStyle(MenuItemStyle())

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(MenuItemStyle())
        }
        .frame(width: 260)
    }
}

private struct MenuRow: View {
    let entry: ServerEntry
    @State private var hovering = false

    var body: some View {
        Button {
            if let url = entry.url { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: 8) {
                Text(verbatim: ":\(entry.port)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(width: 52, alignment: .leading)
                Text(entry.command)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if entry.url != nil {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(hovering ? Color.accentColor.opacity(0.18) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct MenuItemStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(hovering ? Color.accentColor.opacity(0.18) : .clear)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
