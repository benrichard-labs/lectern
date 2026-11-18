import Toybox.Lang;

// GATT layout shared with the Mac app.
// Keep in sync with mac/Lectern/Bluetooth/ClickerProtocol.swift.
module LecternProtocol {
    const SERVICE_UUID = "9d3a29a7-e21d-4e74-975d-17a6b396eea6";
    const COMMAND_UUID = "2c83f3f3-3807-4b1f-b86d-c8cad672e516";

    const CMD_NEXT = 0x01;
    const CMD_PREVIOUS = 0x02;
}
