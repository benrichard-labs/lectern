import SwiftUI

@main
struct LecternApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Lectern", systemImage: model.isWatchConnected ? "play.rectangle.fill" : "play.rectangle") {
            MenuContentView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
