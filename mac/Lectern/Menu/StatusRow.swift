import SwiftUI

struct StatusRow: View {
    let title: LocalizedStringKey
    let isOK: Bool

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: isOK ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isOK ? Color.green : Color.secondary)
        }
    }
}
