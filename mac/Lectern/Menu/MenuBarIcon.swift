import AppKit

/// Template images for the menu bar, one per status. While setup is
/// incomplete the icon carries a small dot, cut out of the symbol so it stays
/// legible at menu bar size.
enum MenuBarIcon {
    static func image(for status: AppModel.Status) -> NSImage {
        switch status {
        case .setup: badged("play.rectangle")
        case .starting, .waiting: symbol("play.rectangle")
        case .paused: symbol("pause.rectangle")
        case .connected: symbol("play.rectangle.fill")
        }
    }

    private static func symbol(_ name: String) -> NSImage {
        let image = makeSymbol(name) ?? NSImage()
        image.isTemplate = true
        return image
    }

    private static func badged(_ name: String) -> NSImage {
        let size = makeSymbol(name)?.size ?? NSSize(width: 18, height: 14)
        let image = NSImage(size: size, flipped: false) { rect in
            MenuBarIcon.drawBadged(name, in: rect)
        }
        image.isTemplate = true
        return image
    }

    private nonisolated static func makeSymbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: "Lectern")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .regular))
    }

    private nonisolated static func drawBadged(_ name: String, in rect: NSRect) -> Bool {
        guard let symbol = makeSymbol(name), let context = NSGraphicsContext.current else { return false }
        symbol.draw(in: rect)

        let diameter: CGFloat = 6
        let dot = NSRect(x: rect.maxX - diameter, y: rect.maxY - diameter, width: diameter, height: diameter)
        NSColor.black.setFill()

        // Clear a ring around the dot, then draw the dot.
        context.compositingOperation = .destinationOut
        NSBezierPath(ovalIn: dot.insetBy(dx: -1.5, dy: -1.5)).fill()
        context.compositingOperation = .sourceOver
        NSBezierPath(ovalIn: dot).fill()
        return true
    }
}
