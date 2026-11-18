import CoreGraphics

/// Synthesizes the arrow-key presses that Keynote, PowerPoint, Google Slides
/// and most PDF viewers treat as next and previous slide.
enum KeyPoster {
    private static let rightArrow: CGKeyCode = 0x7C // kVK_RightArrow
    private static let leftArrow: CGKeyCode = 0x7B // kVK_LeftArrow

    /// Whether macOS lets this process post keyboard events
    /// (Privacy & Security > Accessibility).
    static var isTrusted: Bool {
        CGPreflightPostEventAccess()
    }

    /// Shows the system prompt that points the user at the Accessibility list.
    static func requestAccess() {
        _ = CGRequestPostEventAccess()
    }

    /// Sends a key down and key up to the frontmost app.
    static func post(_ command: ClickerCommand) {
        let keyCode = switch command {
        case .next: rightArrow
        case .previous: leftArrow
        }

        let source = CGEventSource(stateID: .hidSystemState)
        for isKeyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isKeyDown) else {
                continue
            }
            // Hardware arrow keys carry these flags; match them so apps that
            // inspect modifiers see an ordinary arrow press.
            event.flags = [.maskNumericPad, .maskSecondaryFn]
            event.post(tap: .cghidEventTap)
        }
    }
}
