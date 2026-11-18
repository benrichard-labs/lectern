import AppKit
import SwiftUI

/// The panel shown when clicking the menu bar icon.
struct MenuContentView: View {
    @Bindable var model: AppModel
    @State private var launchesAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lectern")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                StatusRow(title: bluetoothTitle, isOK: model.peripheral.state == .advertising)
                StatusRow(title: watchTitle, isOK: model.isWatchConnected)
            }

            if !model.isTrusted {
                AccessibilityBanner(
                    requestAccess: model.requestAccessibility,
                    openSettings: model.openAccessibilitySettings
                )
            }

            if let command = model.lastCommand, let date = model.lastCommandDate {
                Text("\(command.title), \(Text(date, style: .relative)) ago")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Pause forwarding", isOn: $model.isPaused)
            Toggle("Launch at login", isOn: $launchesAtLogin)

            Divider()

            Button("Quit Lectern") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            model.refreshAccessibility()
            launchesAtLogin = model.launchesAtLogin
        }
        .onChange(of: launchesAtLogin) { _, enabled in
            model.setLaunchesAtLogin(enabled)
            launchesAtLogin = model.launchesAtLogin
        }
        .task(id: model.isTrusted) {
            // macOS doesn't announce Accessibility changes, so poll while the
            // panel is open until access is granted.
            while !model.isTrusted, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                model.refreshAccessibility()
            }
        }
    }

    private var bluetoothTitle: LocalizedStringKey {
        switch model.peripheral.state {
        case .starting: "Starting Bluetooth…"
        case .advertising: "Waiting for watches"
        case .poweredOff: "Bluetooth is off"
        case .unauthorized: "Bluetooth access denied"
        case .unsupported: "Bluetooth LE not supported"
        case .failed(let message): "Bluetooth error: \(message)"
        }
    }

    private var watchTitle: LocalizedStringKey {
        let count = model.peripheral.connectedWatches.count
        return count == 0 ? "No watch connected" : "^[\(count) watch](inflect: true) connected"
    }
}
