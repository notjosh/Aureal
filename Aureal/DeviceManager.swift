import Combine
import Foundation

class DeviceManager {
    static var shared = {
        DeviceManager()
    }()

    private let watcher = USBWatcher()
    private let auraUSBController = AuraUSBController()

    let effectRunner: EffectRunner

    @Published private(set) var devices = [AuraUSBDevice]()

    init() {
        effectRunner = EffectRunner(controller: auraUSBController)

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
        print("device connected, \(device)")
        let usb = AuraUSBDevice(hidDevice: device)

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
    private func onFirmware(device hid: HIDDevice, firmware: Data) {
        if let device = device(id: hid.id) {
            device.firmware = String(data: firmware, encoding: .utf8)
        }

        do {
            try auraUSBController.getConfigurationTable(from: hid)
        } catch {
            print("onFirmware => error: \(error)")
        }
    }

    private func onConfiguration(device hid: HIDDevice, configuration data: Data) {
        // TODO: override configuration where possible

        let configuration = AuraUSBDeviceConfiguration(data: data)

        if let device = device(id: hid.id) {
            device.rgbDevice = configuration.rootDevice
            device.addressables = configuration.addressableDevices

            device.connectionState = .connected

            print("connected!")
        }
    }

    private func device(id: String) -> AuraUSBDevice? {
        devices.first(where: { $0.hidDevice.id == id })
    }
}
