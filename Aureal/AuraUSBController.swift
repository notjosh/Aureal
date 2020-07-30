import Foundation

public extension Notification.Name {
    static let AuraUSBControllerConnectionStateUpdated = Notification.Name("AuraUSBControllerConnectionStateUpdated")
}

enum AuraUSBControllerError: Error {
    case InterfaceUnavailable
    case CommandTooLong
    case InvalidResponse(code: IOReturn)
}

enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

class AuraUSBController {
    private(set) var connectionState = ConnectionState.disconnected {
        didSet {
            NotificationCenter.default.post(name: .AuraUSBControllerConnectionStateUpdated, object: [
                "connectionState": connectionState
            ])
        }
    }
    private(set) var device: HIDDevice
    private var auraUSBDevices = [AuraUSBDevice]()

    init(_ device: HIDDevice) {
        self.device = device
    }

    deinit {
        connectionState = .disconnected
    }

    func handle(data: Data) throws {
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
            handleFirmwareVersion(data.subdata(in: 2..<18))

            // next:
            try getConfigurationTable()
        case 0x30:
            handleConfigurationTable(data.subdata(in: 4..<64))

            connectionState = .connected
        default:
            print("unknown aura command: \(data[1])")
        }
    }

    func handshake() throws {
        connectionState = .connecting

        try getFirmwareVersion()
    }

    static var step: Int = 0
    func send(command: Command) throws {
        // FIXME: this shouldn't need to know directly about EffectCommand

        if let effectCommand = command as? EffectCommand {
            var startLED: UInt8 = 0
            for auraUSBDevice in auraUSBDevices {
                let rgbs = auraUSBDevice.type == .addressable
                    ? [effectCommand.color]
                    : [CommandColor](repeating: effectCommand.color, count: Int(8))

                try setEffect(command: effectCommand, effectChannel: auraUSBDevice.effectChannel)
                try setColors(
                    rgbs,
                    startLED: startLED,
                    channel: auraUSBDevice.effectChannel,
                    isFixed: auraUSBDevice.type == .fixed
                )

                startLED += UInt8(rgbs.count)
            }

            try commit()
        }

        if let directCommand = command as? DirectCommand {
            let ledCountPerCommand = 20

            for auraUSBDevice in auraUSBDevices {
                var startLED: UInt8 = 0

                let rgbs = directCommand.rgbs(
                    capacity: Int(auraUSBDevice.numberOfLEDs),
                    step: type(of: self).step
                )

                let groups = rgbs.chunked(into: ledCountPerCommand)
                for (index, group) in groups.enumerated() {
                    try setDirect(
                        group,
                        startLED: startLED,
                        channel: auraUSBDevice.directChannel,
                        apply: index >= groups.count - 1
                    )

                    startLED += UInt8(group.count)
                }
            }

            type(of: self).step += 1
        }
    }

    func getFirmwareVersion() throws {
        try send(commandBytes: [
            AuraCommand,
            0x82,
        ])
    }

    func getConfigurationTable() throws {
        // 0xB0
        try send(commandBytes: [
            AuraCommand,
            0xb0,
        ])
    }

    func setDirect(_ rgbs: [CommandColor], startLED: UInt8, channel: UInt8, apply: Bool) throws {
//        print(rgbs.count)
        try send(
            commandBytes: [
                AuraCommand,
                0x40,
                (apply ? 0x80 : 0x00) | channel,
                startLED,
                UInt8(rgbs.count)
            ]
            + rgbs.flatMap { [$0.r, $0.g, $0.b] }
        )
    }
    
    func setEffect(command: EffectCommand, effectChannel: UInt8) throws {
        try send(commandBytes: [
            AuraCommand,
            0x35, // "effect control mode"
            effectChannel,
            0x0, // unknown
            0x0, // unknown
            UInt8(command.effect.rawValue),
        ])
    }
    
    func setColors(_ rgbs: [CommandColor], startLED: UInt8, channel: UInt8, isFixed: Bool) throws {
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
                + rgbs.flatMap { [$0.r, $0.g, $0.b] }
        )
    }
    
    func commit() throws {
        try send(commandBytes: [
            AuraCommand,
            0x3f,
            0x55
        ])
    }
        
    private func send(commandBytes: [UInt8]) throws {
        guard commandBytes.count <= AuraCommandLength else {
            throw AuraUSBControllerError.CommandTooLong
        }

        var bytes = commandBytes + [UInt8](
            repeating: 0,
            count: AuraCommandLength - commandBytes.count
        )

//        print(bytes.count, bytes.hexa)

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

    private func handleFirmwareVersion(_ data: Data) {
        print("firmware: \(data)")

        let name = String(decoding: data, as: UTF8.self)

        print(name)
    }

    private func handleConfigurationTable(_ data: Data) {
        print("config: \(data)")

        for i in stride(from: 0, to: data.count, by: 6) {
            print(
                String(
                    format: "%02X: %02X %02X %02X %02X %02X %02X ",
                    arguments: [
                        i,
                        data[i + 0],
                        data[i + 1],
                        data[i + 2],
                        data[i + 3],
                        data[i + 4],
                        data[i + 5],
                    ]
                )
            )
        }

        // config: 60 bytes
//        00: 1E 9F 02 01 00 00 <- 2 addressable devices
//        06: 78 3C 00 01 00 00 <- addressable device 1: 0x78 (100) LEDs
//        0C: 78 3C 00 00 00 00 <- addressable device 2: 0x78 (100) LEDs
//        12: 00 00 00 00 00 00
//        18: 00 00 00 08 0A 02 <- mainboard: 8 mainboard LEDs
//        1E: 01 F4 00 00 00 00
//        24: 00 00 00 00 00 00
//        2A: 00 00 00 00 00 00
//        30: 00 00 00 00 00 00
//        36: 00 00 00 00 00 00

        let addressableChannelCount = data[0x02]
        let mainboardLEDCount = data[0x1b]

        print("addressableChannelCount: \(addressableChannelCount)")
        print("mainboardLEDCount: \(mainboardLEDCount)")

        configureForDevices(
            count: addressableChannelCount,
            mainboardLEDCount: mainboardLEDCount
        )
    }

    private func configureForDevices(count: UInt8, mainboardLEDCount: UInt8) {
        auraUSBDevices.removeAll()

        // mainboard
        auraUSBDevices.append(
            .init(effectChannel: 0x0, directChannel: 0x4, numberOfLEDs: mainboardLEDCount, type: .fixed)
        )

        // addressables
        auraUSBDevices.append(contentsOf:
            (0..<count).map { index -> AuraUSBDevice in
                .init(
                    effectChannel: index + 1,
                    directChannel: index,
                    numberOfLEDs: 0x78, // TODO: <- hardcoded for now
                    type: .addressable
                )
            }
        )
    }
}
