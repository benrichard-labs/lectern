import CoreBluetooth

/// The GATT layout shared with the Garmin watch app.
///
/// Keep these values in sync with `garmin/source/Protocol.mc`.
enum ClickerProtocol {
    /// Primary service the Mac advertises and the watch scans for.
    static let serviceUUID = CBUUID(string: "9D3A29A7-E21D-4E74-975D-17A6B396EEA6")

    /// Characteristic the watch writes one-byte commands to. The watch also
    /// subscribes to it, which is how the Mac learns a watch is connected.
    static let commandUUID = CBUUID(string: "2C83F3F3-3807-4B1F-B86D-C8CAD672E516")
}
