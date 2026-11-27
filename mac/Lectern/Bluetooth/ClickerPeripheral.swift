import CoreBluetooth
import Observation
import OSLog

/// Advertises the Lectern GATT service so the watch, acting as a BLE central,
/// can connect and write slide commands.
@Observable
final class ClickerPeripheral: NSObject {
    enum State: Equatable {
        case starting
        case advertising
        case poweredOff
        case unauthorized
        case unsupported
        case failed(String)
    }

    private(set) var state: State = .starting

    /// Watches subscribed to the command characteristic.
    ///
    /// A peripheral gets no callback when a central merely connects, so a
    /// subscription is the presence signal. CoreBluetooth reports an
    /// unsubscribe when a subscribed central disconnects.
    private(set) var connectedWatches: Set<UUID> = []

    /// When the Mac started advertising with no watch connected, or nil while
    /// a watch is connected or Bluetooth isn't advertising.
    private(set) var waitingSince: Date?

    @ObservationIgnored var onCommand: (@MainActor (ClickerCommand) -> Void)?
    @ObservationIgnored private var manager: CBPeripheralManager?
    @ObservationIgnored private let logger = Logger(subsystem: "com.benjaminrichard.Lectern", category: "Bluetooth")

    func start() {
        guard manager == nil else { return }
        // A nil queue delivers delegate callbacks on the main queue, which
        // matches this type's main-actor isolation.
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Publishes the service and advertises again, after a failure.
    func restart() {
        guard let manager else {
            start()
            return
        }
        manager.stopAdvertising()
        waitingSince = nil
        state = .starting
        if manager.state == .poweredOn {
            publishService(on: manager)
        } else {
            peripheralManagerDidUpdateState(manager)
        }
    }

    private func publishService(on manager: CBPeripheralManager) {
        manager.removeAllServices()

        let command = CBMutableCharacteristic(
            type: ClickerProtocol.commandUUID,
            properties: [.write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.writeable]
        )
        let service = CBMutableService(type: ClickerProtocol.serviceUUID, primary: true)
        service.characteristics = [command]
        manager.add(service)
    }
}

extension ClickerPeripheral: @MainActor CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        connectedWatches.removeAll()
        waitingSince = nil

        switch peripheral.state {
        case .poweredOn:
            publishService(on: peripheral)
        case .poweredOff:
            state = .poweredOff
        case .unauthorized:
            state = .unauthorized
        case .unsupported:
            state = .unsupported
        case .resetting, .unknown:
            state = .starting
        @unknown default:
            state = .starting
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        if let error {
            logger.error("Adding service failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
            return
        }

        // Advertise the service UUID and nothing else. Connect IQ scans
        // passively: the watch only sees the primary advertising packet,
        // never the scan response. A 128-bit UUID already takes 18 of its 31
        // bytes, and macOS decides on its own how to pack and split the
        // fields, so anything extra risks pushing the UUID out of the
        // packet the watch can see. The watch doesn't use a name.
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [ClickerProtocol.serviceUUID],
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        if let error {
            logger.error("Advertising failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        } else {
            logger.info("Advertising Lectern service")
            state = .advertising
            if connectedWatches.isEmpty {
                waitingSince = .now
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        logger.info("Watch connected: \(central.identifier)")
        connectedWatches.insert(central.identifier)
        waitingSince = nil
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        logger.info("Watch disconnected: \(central.identifier)")
        connectedWatches.remove(central.identifier)
        if connectedWatches.isEmpty, state == .advertising {
            waitingSince = .now
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let first = requests.first else { return }

        // A batch of ATT writes is all-or-nothing: validate before acting.
        guard requests.allSatisfy({ $0.characteristic.uuid == ClickerProtocol.commandUUID }) else {
            peripheral.respond(to: first, withResult: .requestNotSupported)
            return
        }
        peripheral.respond(to: first, withResult: .success)

        for request in requests {
            for byte in request.value ?? Data() {
                if let command = ClickerCommand(rawValue: byte) {
                    onCommand?(command)
                } else {
                    logger.notice("Ignoring unknown command byte 0x\(String(byte, radix: 16))")
                }
            }
        }
    }
}
