import AppKit
import Observation

/// The app that receives Lectern's arrow keys: the most recently active app
/// other than Lectern itself. Opening the menu panel can make Lectern the
/// active app, so the frontmost app alone isn't the answer.
@Observable
final class TargetApp: NSObject {
    private(set) var app: NSRunningApplication?

    var name: String? {
        app?.localizedName
    }

    var icon: NSImage? {
        app?.icon
    }

    override init() {
        super.init()

        let workspace = NSWorkspace.shared
        if let front = workspace.frontmostApplication, !Self.isLectern(front) {
            app = front
        }

        let center = workspace.notificationCenter
        center.addObserver(self, selector: #selector(didActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(didTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    @objc private func didActivate(_ notification: Notification) {
        guard let activated = Self.application(in: notification), !Self.isLectern(activated) else { return }
        app = activated
    }

    @objc private func didTerminate(_ notification: Notification) {
        guard let ended = Self.application(in: notification),
              ended.processIdentifier == app?.processIdentifier else { return }
        app = nil
    }

    private static func application(in notification: Notification) -> NSRunningApplication? {
        notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    private static func isLectern(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == ProcessInfo.processInfo.processIdentifier
    }
}
