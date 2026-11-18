import AppKit
import Observation
import OSLog
import ServiceManagement

/// Routes commands from the watch to synthetic key presses.
@Observable
final class AppModel {
    let peripheral = ClickerPeripheral()

    /// When paused, commands are received and shown but not forwarded.
    var isPaused = false

    private(set) var isTrusted = KeyPoster.isTrusted
    private(set) var lastCommand: ClickerCommand?
    private(set) var lastCommandDate: Date?

    @ObservationIgnored private let logger = Logger(subsystem: "com.benjaminrichard.Lectern", category: "App")

    var isWatchConnected: Bool {
        !peripheral.connectedWatches.isEmpty
    }

    var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    init() {
        peripheral.onCommand = { [weak self] command in
            self?.handle(command)
        }
        peripheral.start()
    }

    func refreshAccessibility() {
        isTrusted = KeyPoster.isTrusted
    }

    func requestAccessibility() {
        KeyPoster.requestAccess()
        refreshAccessibility()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        guard enabled != launchesAtLogin else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Updating login item failed: \(error.localizedDescription)")
        }
    }

    private func handle(_ command: ClickerCommand) {
        lastCommand = command
        lastCommandDate = .now

        guard !isPaused else { return }

        refreshAccessibility()
        guard isTrusted else {
            logger.notice("Dropping \(command.title): Accessibility permission not granted")
            return
        }
        KeyPoster.post(command)
    }
}
