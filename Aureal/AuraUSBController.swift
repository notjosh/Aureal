import Foundation

public extension Notification.Name {
    static let AuraUSBControllerConnectionStateUpdated = Notification.Name("AuraUSBControllerConnectionStateUpdated")
}

enum AuraUSBControllerError: Error {
    case CommandTooLong
    case InvalidResponse(code: IOReturn)
}

class AuraUSBController {
    var onFirmware: ((HIDDevice, Data) -> Void)?
    var onConfiguration: ((HIDDevice, Data) -> Void)?

    func handle(data: Data, for device: HIDDevice) throws {
        guard data.count == AuraCommandLength else {
            print("Expected length \(AuraCommandLength), got: \(data.count). Ignoring.")
            return
        }
        
        guard data[0] == AuraCommand else {
            print("not an aura command, ignoring")
            return
        }

        switch data[1] {
        case 0x02:
            onFirmware?(device, data.subdata(in: 2..<18))
        case 0x30:
            onConfiguration?(device, data.subdata(in: 4..<64))
        default:
            print("unknown aura command: \(data[1])")
        }
    }

    func getFirmwareVersion(from device: HIDDevice) throws {
        try send(commandBytes: [
            AuraCommand,
            0x82,
        ], to: device)
    }

    func getConfigurationTable(from device: HIDDevice) throws {
        // 0xB0
        try send(commandBytes: [
            AuraCommand,
            0xb0,
        ], to: device)
    }

    func setDirect(_ rgbs: [CommandColor], startLED: UInt8, channel: UInt8, apply: Bool, to device: HIDDevice) throws {
        try send(
            commandBytes: [
                AuraCommand,
                0x40,
                (apply ? 0x80 : 0x00) | channel,
                startLED,
                UInt8(rgbs.count)
            ]
            + rgbs.flatMap { [$0.r, $0.g, $0.b] },
            to: device
        )
    }
    
    func setEffect(effect: AuraEffect, effectChannel: UInt8, to device: HIDDevice) throws {
        try send(commandBytes: [
            AuraCommand,
            0x35, // "effect control mode"
            effectChannel,
            0x0, // unknown
            0x0, // unknown
            UInt8(effect.rawValue),
        ], to: device)
    }
    
    func setColors(_ rgbs: [CommandColor], startLED: UInt8, channel: UInt8, isFixed: Bool, to device: HIDDevice) throws {
        if rgbs.count == 0 {
            return
        }
        
        try send(
            commandBytes: [
                AuraCommand,
                0x36,
                channel,
                isFixed ? 0xff : 0x0,
                0x0, // dunno
                ]
                + [UInt8](repeating: 0, count: Int(startLED) * 3)
                + rgbs.flatMap { [$0.r, $0.g, $0.b] },
            to: device
        )
    }
    
    func commit(to device: HIDDevice) throws {
        try send(commandBytes: [
            AuraCommand,
            0x3f,
            0x55
        ], to: device)
    }
        
    private func send(commandBytes: [UInt8], to device: HIDDevice) throws {
        guard commandBytes.count <= AuraCommandLength else {
            throw AuraUSBControllerError.CommandTooLong
        }

        var bytes = commandBytes + [UInt8](
            repeating: 0,
            count: AuraCommandLength - commandBytes.count
        )

        let response = IOHIDDeviceSetReport(
            device.device,
            kIOHIDReportTypeOutput,
            CFIndex(AuraCommand),
            &bytes,
            bytes.count
        )

        if response != kIOReturnSuccess {
            let systemError = String(format:"%02X", ((response >> 26) & 0x3f))
            let subError =  String(format:"%02X", ((response >> 14) & 0xfff))
            let codeError = String(format:"%02X",  ( response & 0x3fff))

            print("HID error: \(systemError), \(subError), \(codeError)")

            throw AuraUSBControllerError.InvalidResponse(code: response)
        }
    }
}
