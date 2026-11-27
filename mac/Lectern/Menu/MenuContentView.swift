import AppKit
import SwiftUI

/// The panel shown when clicking the menu bar icon.
struct MenuContentView: View {
    @Bindable var model: AppModel
    @State private var launchesAtLogin = false
    @State private var showsHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusHeader(model: model)

            if showsHelp {
                TroubleshootingView { showsHelp = false }
            } else if model.status == .setup {
                SetupChecklist(model: model)
            } else {
                if showsLastClick, let command = model.lastCommand, let date = model.lastCommandDate {
                    LastClickCard(
                        command: command,
                        date: date,
                        wasSent: model.lastCommandWasSent,
                        serial: model.commandSerial,
                        forwardCount: model.forwardCount,
                        backCount: model.backCount
                    )
                }

                PanelGroup {
                    PanelRow {
                        if let icon = model.target.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                        }
                        Text("Slides go to")
                        Spacer(minLength: 8)
                        Text(model.target.name ?? String(localized: "Frontmost app"))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Divider()
                    PanelRow {
                        Text("Send clicks to the Mac")
                        Spacer(minLength: 8)
                        Toggle("Send clicks to the Mac", isOn: $model.isForwarding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                }

                if model.status == .waiting {
                    StuckHint(waitingSince: model.peripheral.waitingSince) { showsHelp = true }
                }
            }

            Divider()

            HStack(spacing: 10) {
                Toggle("Launch at login", isOn: $launchesAtLogin)
                    .toggleStyle(.checkbox)
                Spacer()
                Button {
                    showsHelp.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Troubleshooting")
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("q")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 300)
        .animation(.default, value: model.status)
        .animation(.default, value: showsHelp)
        .onAppear {
            model.refreshAccessibility()
            launchesAtLogin = model.launchesAtLogin
        }
        .onChange(of: launchesAtLogin) { _, enabled in
            model.setLaunchesAtLogin(enabled)
            launchesAtLogin = model.launchesAtLogin
        }
    }

    private var showsLastClick: Bool {
        model.status == .connected || model.status == .paused
    }
}

/// A rounded, lightly filled group of rows, like a section in System Settings.
struct PanelGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 10)
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8))
    }
}

struct PanelRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .frame(minHeight: 30)
    }
}

/// Appears after half a minute of waiting, linking to the troubleshooting tips.
private struct StuckHint: View {
    let waitingSince: Date?
    let showHelp: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            if let waitingSince, context.date.timeIntervalSince(waitingSince) > 30 {
                Button("Watch stuck on “Looking for Mac”?", action: showHelp)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }
}
