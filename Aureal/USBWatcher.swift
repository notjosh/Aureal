import Foundation

class USBWatcher {
    private let deviceMonitor = HIDDeviceMonitor(
        AuraProductIDs.map {
            HIDMonitorData(
                vendorId: AsusUSBVendorID,
                productId: $0
            )
        },
        reportSize: AuraCommandLength
    )

    private lazy var daemon: Thread = {
        Thread(target: deviceMonitor, selector: #selector(deviceMonitor.start), object: nil)
    }()

    var onDeviceConnected: ((HIDDevice) -> Void)?
    var onDeviceDisconnected: ((String) -> Void)?
    var onDeviceData: ((HIDDevice, Data) -> Void)?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.hidDeviceConnected), name: .HIDDeviceConnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.hidDeviceDisconnected), name: .HIDDeviceDisconnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.hidDeviceDataReceived), name: .HIDDeviceDataReceived, object: nil)
    }

    func start() {
        daemon.start()
    }

    func stop() {
        daemon.cancel()
    }

    @objc
    private func hidDeviceConnected(notification: NSNotification) {
        guard
            let obj = notification.object as? NSDictionary,
            let device = obj["device"] as? HIDDevice
            else {
                return
        }

        onDeviceConnected?(device)
    }

    @objc
    private func hidDeviceDisconnected(notification: NSNotification) {
        guard
            let obj = notification.object as? NSDictionary,
            let id = obj["id"] as? String
            else {
                return
        }

        onDeviceDisconnected?(id)
    }

    @objc
    private func hidDeviceDataReceived(notification: NSNotification) {
        guard
            let obj = notification.object as? NSDictionary,
            let data = obj["data"] as? Data,
            let device = obj["device"] as? HIDDevice
            else {
                return
        }

        onDeviceData?(device, data)
    }
}
