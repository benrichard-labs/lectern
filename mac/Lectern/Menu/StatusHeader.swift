import SwiftUI

/// The panel's headline: what Lectern is doing and what to do next.
struct StatusHeader: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint, in: .circle)
                .symbolEffect(.pulse, isActive: model.status == .waiting)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var targetName: String {
        model.target.name ?? String(localized: "the frontmost app")
    }

    private var symbol: String {
        switch model.status {
        case .setup: "exclamationmark"
        case .starting: "antenna.radiowaves.left.and.right"
        case .paused: "pause.fill"
        case .waiting: "applewatch.radiowaves.left.and.right"
        case .connected: "applewatch"
        }
    }

    private var tint: Color {
        switch model.status {
        case .setup: .orange
        case .starting, .paused: .gray
        case .waiting: .accentColor
        case .connected: .green
        }
    }

    private var title: String {
        switch model.status {
        case .setup:
            String(localized: "Finish setup")
        case .starting:
            String(localized: "Starting Bluetooth…")
        case .paused:
            String(localized: "Paused")
        case .waiting:
            String(localized: "Waiting for your watch")
        case .connected:
            model.peripheral.connectedWatches.count == 1
                ? String(localized: "Watch connected")
                : String(localized: "\(model.peripheral.connectedWatches.count) watches connected")
        }
    }

    private var subtitle: String {
        switch model.status {
        case .setup:
            model.stepsLeft == 1
                ? String(localized: "One step left before your watch can change slides.")
                : String(localized: "\(model.stepsLeft) steps left before your watch can change slides.")
        case .starting:
            String(localized: "This takes a moment.")
        case .paused:
            String(localized: "Clicks from the watch are received but not sent to \(targetName).")
        case .waiting:
            String(localized: "Open Lectern on the watch. It connects in a few seconds.")
        case .connected:
            String(localized: "Clicks go to \(targetName).")
        }
    }
}
