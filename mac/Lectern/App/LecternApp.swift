import SwiftUI

@main
struct LecternApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: model.status))
                .accessibilityLabel("Lectern")
        }
        .menuBarExtraStyle(.window)
    }
}
