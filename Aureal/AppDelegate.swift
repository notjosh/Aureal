import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
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
    
    static var shared: AppDelegate {
        NSApp.delegate as! AppDelegate
    }
    
    var controller: AuraUSBController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.hidDeviceConnected), name: .HIDDeviceConnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.hidDeviceDisconnected), name: .HIDDeviceDisconnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.hidDeviceDataReceived), name: .HIDDeviceDataReceived, object: nil)

        daemon.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc
    private func hidDeviceConnected(notification: NSNotification) {
        guard
            let obj = notification.object as? NSDictionary,
            let device = obj["device"] as? HIDDevice
            else {
                return
        }

        print("connected: \(device)")

        do {
            let controller = AuraUSBController(device)
            try controller.handshake()

            self.controller = controller
        } catch {
            print("error connecting USB: \(error)")
        }
    }

    @objc
    private func hidDeviceDisconnected(notification: NSNotification) {
        guard
            let obj = notification.object as? NSDictionary,
            let id = obj["id"] as? String,
            controller?.device.id == id
            else {
                return
        }

        print("disconnected: \(id)")
        
        controller = nil
    }

    @objc
    private func hidDeviceDataReceived(notification: NSNotification) {
        guard
            let obj = notification.object as? NSDictionary,
            let data = obj["data"] as? Data
            else {
                return
        }

        try? controller?.handle(data: data)
    }
}
