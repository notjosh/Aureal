import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate {
        NSApp.delegate as! AppDelegate
    }

    let deviceManager = DeviceManager.shared
    var effectRunner: EffectRunner?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        deviceManager.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        deviceManager.stop()
    }
}
