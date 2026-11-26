import SwiftUI

/// Tips shown in place of the panel's controls. They read the diagnostics
/// line the watch shows while it's looking for the Mac.
struct TroubleshootingView: View {
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Troubleshooting")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Done", action: close)
                    .controlSize(.small)
            }

            Text("While it's looking for the Mac, the watch shows **BLE n / Mac m** at the bottom of its screen.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

            Tip(title: "BLE 0", text: "The watch hears no Bluetooth at all. Restart the watch.")
            Tip(title: "BLE above 0, Mac 0", text: "The watch doesn't see this Mac. Turn Bluetooth off and on here, then reopen Lectern on the watch.")
            Tip(title: "Mac keeps rising", text: "The watch finds this Mac but can't connect. The orange line on the watch says why. Quit Lectern on the watch and open it again.")
            Tip(title: "Slides don't move", text: "Make sure the presentation is the frontmost app and Send clicks to the Mac is on.")
        }
    }
}

private struct Tip: View {
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
