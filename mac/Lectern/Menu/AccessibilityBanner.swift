import SwiftUI

/// Explains why Lectern needs Accessibility access and offers ways to grant it.
struct AccessibilityBanner: View {
    let requestAccess: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.bold())
                .foregroundStyle(.orange)

            Text("Lectern sends arrow keys to Keynote or PowerPoint, which macOS only allows for apps in Privacy & Security > Accessibility.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Grant Access…", action: requestAccess)
                Button("Open Settings", action: openSettings)
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: .rect(cornerRadius: 8))
    }
}
