import Foundation

class DeviceManager {
    static let shared = DeviceManager()

    private let watcher = USBWatcher()
    private let auraUSBController = AuraUSBController()

    private(set) var devices = [AuraUSBDevice]()

    init() {
        // TODO: load saved devices from prefs

        watcher.onDeviceConnected = onDeviceConnected(device:)
        watcher.onDeviceDisconnected = onDeviceDisconnected(deviceID:)
        watcher.onDeviceData = onDeviceData(device:data:)

        auraUSBController.onFirmware = onFirmware(device:firmware:)
        auraUSBController.onConfiguration = onConfiguration(device:configuration:)
    }

    func start() {
        watcher.start()
    }

    func stop() {
        watcher.stop()
    }

    // MARK: USBWatcher
    private func onDeviceConnected(device: HIDDevice) {
        var usb = AuraUSBDevice(hidDevice: device)

        do {
            try auraUSBController.getFirmwareVersion(from: device)
        } catch {
            print("onDeviceConnected => error: \(error)")
        }

        usb.connectionState = .connecting
        devices.append(usb)
    }

    private func onDeviceDisconnected(deviceID: String) {
        devices.removeAll(where: { $0.hidDevice.id == deviceID })
    }

    private func onDeviceData(device: HIDDevice, data: Data) {
        do {
            try auraUSBController.handle(data: data, for: device)
        } catch {
            print("onDeviceData => error: \(error)")
        }
    }

    // MARK: AuraUSBController
    private func onFirmware(device: HIDDevice, firmware: Data) {

        do {
            try auraUSBController.getConfigurationTable(from: device)
        } catch {
            print("onFirmware => error: \(error)")
        }
    }

    private func onConfiguration(device: HIDDevice, configuration: Data) {
        // TODO: override configuration where possible

        print("boop", configuration)
    }
}
