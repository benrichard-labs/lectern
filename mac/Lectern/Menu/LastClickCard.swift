import SwiftUI

/// The last command from the watch as a key cap that bounces on each press,
/// with how long ago it came and the session's counts.
struct LastClickCard: View {
    let command: ClickerCommand
    let date: Date
    let wasSent: Bool
    let serial: Int
    let forwardCount: Int
    let backCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: command == .next ? "arrow.right" : "arrow.left")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 30)
                .background(.background, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                .symbolEffect(.bounce, value: serial)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(wasSent ? command.title : String(localized: "\(command.title) (not sent)"))
                    .fontWeight(.semibold)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let ago = date.formatted(.relative(presentation: .named, unitsStyle: .wide))
        let when = ago.prefix(1).uppercased() + ago.dropFirst()
        guard forwardCount + backCount > 0 else { return when }
        return String(localized: "\(when) · \(forwardCount) forward, \(backCount) back")
    }
}
