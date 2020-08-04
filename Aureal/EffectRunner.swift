import Foundation

class EffectRunner {
    var effect: Command?

    private let controller: AuraUSBController

    init(controller: AuraUSBController) {
        self.controller = controller
    }

    var step: Int = 0
    var isDirect = false

    var command: Command?
    var device: AuraUSBDevice?
    var allAddressables = [AuraConnectedDevice]()

    private var observation: Any? = nil
    private var activity: NSObjectProtocol?
    private var timer: Timer?

    deinit {
        timer?.invalidate()
        timer = nil
        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
    }

    func run(command: Command?, on device: AuraUSBDevice) throws {
        step = 0

        self.command = command
        self.device = device
        self.allAddressables = [device.rgbDevice].compactMap { $0 } + device.addressables


        timer?.invalidate()
        timer = nil

        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
        }

        if command is DirectCommand {
            let interval: TimeInterval = 0.01
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                do {
                    try self?.tick()
                } catch {
                    print("oh no: ", error)
                }
            }
            timer.tolerance = interval
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer

            activity = ProcessInfo
                .processInfo
                .beginActivity(
                    options: .userInitiated,
                    reason: "Animating RGBs"
                )
        }

        try tick()
    }

    private func tick() throws {
        guard let device = device else {
            return
        }

        // FIXME: this shouldn't need to know directly about EffectCommand
        if let effectCommand = command as? EffectCommand {
            isDirect = false
            var startLED: UInt8 = 0
            for auraUSBDevice in allAddressables {
                let rgbs = auraUSBDevice.type == .addressable
                    ? [effectCommand.color]
                    : [CommandColor](repeating: effectCommand.color, count: Int(8))

                try controller.setEffect(effect: effectCommand.effect, effectChannel: auraUSBDevice.effectChannel, to: device.hidDevice)
                try controller.setColors(
                    rgbs,
                    startLED: startLED,
                    channel: auraUSBDevice.effectChannel,
                    isFixed: auraUSBDevice.type == .fixed,
                    to: device.hidDevice
                )

                startLED += UInt8(rgbs.count)
            }

            try controller.commit(to: device.hidDevice)
        }

        if let directCommand = command as? DirectCommand {
            let ledCountPerCommand = 20

            for auraUSBDevice in allAddressables {
                if !isDirect {
                    try controller.setEffect(
                        effect: .direct,
                        effectChannel: auraUSBDevice.effectChannel,
                        to: device.hidDevice
                    )
                }

                var startLED: UInt8 = 0

                let rgbs = directCommand.rgbs(
                    capacity: Int(auraUSBDevice.numberOfLEDs),
                    step: step
                )

                let groups = rgbs.chunked(into: ledCountPerCommand)
                for (index, group) in groups.enumerated() {
                    try controller.setDirect(
                        group,
                        startLED: startLED,
                        channel: auraUSBDevice.directChannel,
                        apply: index >= groups.count - 1,
                        to: device.hidDevice
                    )

                    startLED += UInt8(group.count)
                }
            }

            isDirect = true

            step += 1
        }
    }
}
