import SwiftUI

/// Shown until Bluetooth and the key-press permission both work. Each
/// missing step has a button that fixes it.
struct SetupChecklist: View {
    let model: AppModel

    var body: some View {
        PanelGroup {
            SetupStep("Bluetooth", isDone: model.isBluetoothReady) {
                bluetoothAction
            }
            Divider()
            SetupStep("Send key presses", isDone: model.isTrusted) {
                if model.isTrusted {
                    Text("Allowed")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Allow…", action: model.requestAccessibility)
                        .buttonStyle(.borderedProminent)
                        .help("Lectern sends arrow keys to Keynote or PowerPoint, which macOS only allows for apps in Privacy & Security › Accessibility.")
                }
            }
            Divider()
            SetupStep("Watch", isDone: model.isWatchConnected) {
                Text(model.isWatchConnected ? "Connected" : "Open Lectern on it")
                    .foregroundStyle(.secondary)
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var bluetoothAction: some View {
        switch model.peripheral.state {
        case .advertising:
            Text("On")
                .foregroundStyle(.secondary)
        case .starting:
            ProgressView()
                .controlSize(.mini)
        case .poweredOff:
            Button("Turn On…") { model.open(.bluetooth) }
                .help("Bluetooth is off. Turn it on in System Settings.")
        case .unauthorized:
            Button("Allow…") { model.open(.bluetoothPrivacy) }
                .help("Allow Lectern under Privacy & Security › Bluetooth.")
        case .unsupported:
            Text("Not available")
                .foregroundStyle(.secondary)
                .help("This Mac can't advertise a Bluetooth LE service.")
        case .failed(let message):
            Button("Try Again", action: model.peripheral.restart)
                .help(message)
        }
    }
}

private struct SetupStep<Accessory: View>: View {
    let title: LocalizedStringKey
    let isDone: Bool
    let accessory: Accessory

    init(_ title: LocalizedStringKey, isDone: Bool, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.isDone = isDone
        self.accessory = accessory()
    }

    var body: some View {
        PanelRow {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isDone ? Color.green : Color.secondary)
            Text(title)
            Spacer(minLength: 8)
            accessory
                .font(.caption)
        }
    }
}
