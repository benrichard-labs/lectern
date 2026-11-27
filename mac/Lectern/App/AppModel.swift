import AppKit
import Observation
import OSLog
import ServiceManagement

/// Routes commands from the watch to synthetic key presses, and sums up the
/// app's state for the menu bar and its panel.
@Observable
final class AppModel {
    /// The one thing the menu panel leads with, most urgent first.
    enum Status: Equatable {
        /// Bluetooth or the key-press permission needs fixing.
        case setup
        case starting
        case paused
        case waiting
        case connected
    }

    enum SettingsPane {
        case accessibility
        case bluetooth
        case bluetoothPrivacy

        var url: URL? {
            switch self {
            case .accessibility:
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            case .bluetooth:
                URL(string: "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension")
            case .bluetoothPrivacy:
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
            }
        }
    }

    let peripheral = ClickerPeripheral()
    let target = TargetApp()

    /// Whether commands from the watch become key presses. When off, commands
    /// are still received and shown but not sent.
    var isForwarding = true

    private(set) var isTrusted = KeyPoster.isTrusted
    private(set) var lastCommand: ClickerCommand?
    private(set) var lastCommandDate: Date?
    private(set) var lastCommandWasSent = false
    /// Increases with every command received, so views can react to each one.
    private(set) var commandSerial = 0
    /// Commands sent as key presses since launch.
    private(set) var forwardCount = 0
    private(set) var backCount = 0

    @ObservationIgnored private var accessibilityPoll: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.benjaminrichard.Lectern", category: "App")

    private static let didRequestAccessibilityKey = "didRequestAccessibility"

    var isBluetoothReady: Bool {
        peripheral.state == .advertising
    }

    var isWatchConnected: Bool {
        !peripheral.connectedWatches.isEmpty
    }

    var status: Status {
        switch peripheral.state {
        case .poweredOff, .unauthorized, .unsupported, .failed:
            return .setup
        case .starting, .advertising:
            break
        }
        if !isTrusted {
            return .setup
        }
        if peripheral.state == .starting {
            return .starting
        }
        if !isForwarding {
            return .paused
        }
        return isWatchConnected ? .connected : .waiting
    }

    /// Setup steps still missing: Bluetooth, key presses, watch.
    var stepsLeft: Int {
        [isBluetoothReady, isTrusted, isWatchConnected].filter { !$0 }.count
    }

    var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    init() {
        peripheral.onCommand = { [weak self] command in
            self?.handle(command)
        }
        peripheral.start()
        watchAccessibility()
    }

    func refreshAccessibility() {
        isTrusted = KeyPoster.isTrusted
        watchAccessibility()
    }

    /// Shows the system prompt the first time. macOS only shows it once, so
    /// later attempts open the Accessibility list in System Settings.
    func requestAccessibility() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.didRequestAccessibilityKey) {
            open(.accessibility)
        } else {
            defaults.set(true, forKey: Self.didRequestAccessibilityKey)
            KeyPoster.requestAccess()
        }
        refreshAccessibility()
    }

    func open(_ pane: SettingsPane) {
        guard let url = pane.url else { return }
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

    // macOS doesn't announce Accessibility changes, so check every couple of
    // seconds until access is granted. That keeps the menu bar icon current
    // even while the panel is closed.
    private func watchAccessibility() {
        guard !isTrusted, accessibilityPoll == nil else { return }
        accessibilityPoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                self.isTrusted = KeyPoster.isTrusted
                if self.isTrusted {
                    self.accessibilityPoll = nil
                    return
                }
            }
        }
    }

    private func handle(_ command: ClickerCommand) {
        lastCommand = command
        lastCommandDate = .now
        commandSerial += 1
        lastCommandWasSent = forward(command)

        guard lastCommandWasSent else { return }
        switch command {
        case .next: forwardCount += 1
        case .previous: backCount += 1
        }
    }

    private func forward(_ command: ClickerCommand) -> Bool {
        guard isForwarding else { return false }

        refreshAccessibility()
        guard isTrusted else {
            logger.notice("Dropping \(command.title): Accessibility permission not granted")
            return false
        }
        KeyPoster.post(command)
        return true
    }
}
