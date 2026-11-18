/// A single-byte command written by the watch to the command characteristic.
nonisolated enum ClickerCommand: UInt8, Sendable {
    case next = 0x01
    case previous = 0x02

    var title: String {
        switch self {
        case .next: "Next slide"
        case .previous: "Previous slide"
        }
    }
}
