import Toybox.Attention;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Link states, shown on screen by LecternView.
enum {
    LINK_STARTING,
    LINK_SCANNING,
    LINK_CONNECTING,
    LINK_READY,
    LINK_ERROR
}

// Finds the Mac advertising the Lectern service, connects to it and writes
// one-byte commands to its command characteristic.
//
// The watch is the BLE central; the Mac is the peripheral. The connection is
// open and unbonded, which sidesteps the fenix pairing bugs.
//
// Connect IQ allows one outstanding BLE request at a time, so commands are
// queued and each is sent once the previous write is acknowledged.
class ClickerLink extends BluetoothLowEnergy.BleDelegate {
    private const MAX_QUEUED = 4;
    private const CONNECT_TIMEOUT_MS = 10000;

    private var _serviceUuid as BluetoothLowEnergy.Uuid;
    private var _commandUuid as BluetoothLowEnergy.Uuid;
    private var _watchdog as Timer.Timer;

    private var _state as Number = LINK_STARTING;
    private var _error as String = "";
    private var _command as BluetoothLowEnergy.Characteristic? = null;
    private var _queue as Array<Number> = [] as Array<Number>;
    private var _busy as Boolean = false;
    private var _inFlight as Number? = null;
    private var _lastSent as Number? = null;

    function initialize() {
        BleDelegate.initialize();
        _serviceUuid = BluetoothLowEnergy.stringToUuid(LecternProtocol.SERVICE_UUID);
        _commandUuid = BluetoothLowEnergy.stringToUuid(LecternProtocol.COMMAND_UUID);
        _watchdog = new Timer.Timer();
    }

    // MARK: Lifecycle

    function start() as Void {
        BluetoothLowEnergy.setDelegate(self);
        unpairAll();
        try {
            BluetoothLowEnergy.registerProfile({
                :uuid => _serviceUuid,
                :characteristics => [{
                    :uuid => _commandUuid,
                    :descriptors => [BluetoothLowEnergy.cccdUuid()]
                }]
            });
        } catch (e) {
            fail("Profile error");
        }
    }

    function stop() as Void {
        _watchdog.stop();
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        unpairAll();
    }

    // MARK: Public API

    function getState() as Number {
        return _state;
    }

    function getError() as String {
        return _error;
    }

    // The most recent command the Mac acknowledged, or null.
    function getLastSent() as Number? {
        return _lastSent;
    }

    function send(command as Number) as Void {
        if (_state != LINK_READY) {
            buzz([350]);
            return;
        }
        if (_queue.size() >= MAX_QUEUED) {
            return;
        }
        _queue.add(command);
        flush();
    }

    // MARK: BleDelegate

    function onProfileRegister(uuid as BluetoothLowEnergy.Uuid, status as BluetoothLowEnergy.Status) as Void {
        if (status == BluetoothLowEnergy.STATUS_SUCCESS) {
            startScan();
        } else {
            fail("Profile error");
        }
    }

    function onScanStateChange(scanState as BluetoothLowEnergy.ScanState, status as BluetoothLowEnergy.Status) as Void {
        if (status != BluetoothLowEnergy.STATUS_SUCCESS && _state == LINK_SCANNING) {
            fail("Scan failed");
        }
    }

    function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        if (_state != LINK_SCANNING) {
            return;
        }
        for (var result = scanResults.next(); result != null; result = scanResults.next()) {
            if (result instanceof BluetoothLowEnergy.ScanResult && advertisesLectern(result)) {
                connect(result);
                return;
            }
        }
    }

    function onConnectedStateChanged(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            if (_state == LINK_CONNECTING) {
                _watchdog.stop();
                subscribe(device);
            }
        } else if (_state == LINK_CONNECTING || _state == LINK_READY) {
            // Ignore late disconnects from devices we already dropped.
            reconnect();
        }
    }

    function onDescriptorWrite(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
        _busy = false;
        // If subscribing failed, writes still work; the Mac just can't show
        // this watch as connected.
        markReady();
    }

    function onCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        _busy = false;
        if (status == BluetoothLowEnergy.STATUS_SUCCESS) {
            _lastSent = _inFlight;
            buzz([40]);
        } else {
            buzz([350]);
        }
        _inFlight = null;
        WatchUi.requestUpdate();
        flush();
    }

    // Called by the watchdog timer when a connection attempt stalls.
    function onConnectTimeout() as Void {
        if (_state == LINK_CONNECTING) {
            reconnect();
        }
    }

    // MARK: Connection steps

    private function startScan() as Void {
        _command = null;
        _busy = false;
        _inFlight = null;
        _queue = [] as Array<Number>;
        _state = LINK_SCANNING;
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
        WatchUi.requestUpdate();
    }

    private function connect(result as BluetoothLowEnergy.ScanResult) as Void {
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        _state = LINK_CONNECTING;
        WatchUi.requestUpdate();

        var device as BluetoothLowEnergy.Device? = null;
        try {
            device = BluetoothLowEnergy.pairDevice(result);
        } catch (e) {
            device = null;
        }

        if (device == null) {
            startScan();
            return;
        }
        _watchdog.stop();
        _watchdog.start(method(:onConnectTimeout), CONNECT_TIMEOUT_MS, false);
    }

    private function subscribe(device as BluetoothLowEnergy.Device) as Void {
        var service = device.getService(_serviceUuid);
        if (service == null) {
            reconnect();
            return;
        }
        var command = service.getCharacteristic(_commandUuid);
        if (command == null) {
            reconnect();
            return;
        }
        _command = command;

        var cccd = command.getDescriptor(BluetoothLowEnergy.cccdUuid());
        if (cccd == null) {
            markReady();
            return;
        }

        // Subscribing is how the Mac learns this watch is connected.
        _busy = true;
        try {
            cccd.requestWrite([0x01, 0x00]b);
        } catch (e) {
            _busy = false;
            markReady();
        }
    }

    private function markReady() as Void {
        _state = LINK_READY;
        buzz([80, 80, 80]);
        WatchUi.requestUpdate();
        flush();
    }

    private function flush() as Void {
        var command = _command;
        if (_busy || command == null || _queue.size() == 0) {
            return;
        }

        var value = _queue[0];
        _queue = _queue.slice(1, null);

        var bytes = new [1]b;
        bytes[0] = value;

        _busy = true;
        _inFlight = value;
        try {
            command.requestWrite(bytes, { :writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE });
        } catch (e) {
            _busy = false;
            _inFlight = null;
            buzz([350]);
        }
    }

    private function reconnect() as Void {
        _watchdog.stop();
        unpairAll();
        startScan();
    }

    private function fail(message as String) as Void {
        _state = LINK_ERROR;
        _error = message;
        WatchUi.requestUpdate();
    }

    // MARK: Helpers

    private function advertisesLectern(result as BluetoothLowEnergy.ScanResult) as Boolean {
        var uuids = result.getServiceUuids();
        for (var uuid = uuids.next(); uuid != null; uuid = uuids.next()) {
            if (uuid.equals(_serviceUuid)) {
                return true;
            }
        }
        return false;
    }

    // Drops every device this app paired. macOS rotates its Bluetooth address,
    // so a fresh scan is more reliable than waiting for an auto-reconnect.
    private function unpairAll() as Void {
        var devices = [] as Array<BluetoothLowEnergy.Device>;
        var paired = BluetoothLowEnergy.getPairedDevices();
        for (var device = paired.next(); device != null; device = paired.next()) {
            devices.add(device as BluetoothLowEnergy.Device);
        }
        for (var i = 0; i < devices.size(); i++) {
            BluetoothLowEnergy.unpairDevice(devices[i]);
        }
    }

    // Vibrates for each duration in milliseconds, pausing between them.
    private function buzz(durations as Array<Number>) as Void {
        if (!(Attention has :vibrate)) {
            return;
        }
        var profile = [] as Array<Attention.VibeProfile>;
        for (var i = 0; i < durations.size(); i++) {
            profile.add(new Attention.VibeProfile(i % 2 == 0 ? 60 : 0, durations[i]));
        }
        Attention.vibrate(profile);
    }
}
