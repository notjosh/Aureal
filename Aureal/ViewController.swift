import Cocoa

class ViewController: NSViewController {
    @IBOutlet private var connectedStatusLabel: NSTextField!
    @IBOutlet private var effectsPopUpButton: NSPopUpButton!
    @IBOutlet private var colorWell: NSColorWell!

    private var currentMode = AuraEffectMode.static
    private var currentColor = NSColor.bestPink

    private var connectionState: ConnectionState {
        AppDelegate.shared.controller?.connectionState ?? .disconnected
    }

    private var observation: Any? = nil

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        observation = NotificationCenter.default.addObserver(
            forName: .AuraUSBControllerConnectionStateUpdated,
            object: nil,
            queue: nil,
            using: { [weak self] notification in
                DispatchQueue.main.async {
                    self?.updateConnectionState()
                }
            }
        )

        connectedStatusLabel.stringValue = "Unknown"

        effectsPopUpButton.removeAllItems()
        for mode in AuraEffectMode.allCases {
            effectsPopUpButton.addItem(withTitle: mode.name)
        }

        // set defaults
        effectsPopUpButton.selectItem(at: AuraEffectMode.allCases.firstIndex(of: currentMode) ?? 0)
        colorWell.color = currentColor
        updateConnectionState()
    }

    @IBAction func handleColor(sender: Any) {
        currentColor = colorWell.color

        update()
    }

    @IBAction func handleEffect(sender: Any) {
        let idx = effectsPopUpButton.indexOfSelectedItem

        guard
            idx >= 0,
            idx < AuraEffectMode.allCases.count
            else {
                return
        }

        currentMode = AuraEffectMode.allCases[idx]

        colorWell.isHidden = !currentMode.colorable

        update()
    }

    private func update() {
        let commandColor = CommandColor(color: currentColor)

        let command = EffectCommand(
            currentMode,
            rgbs: currentMode.colorable ? [commandColor] : []
        )

        send(command)
    }

    private func updateConnectionState() {
        connectedStatusLabel.stringValue = connectionState.description

        if connectionState == .connected {
            update()
        }
    }

    func send(_ command: Command) {
        guard let controller = AppDelegate.shared.controller else {
            print("no controller?")
            return
        }

        do {
            try controller.send(command: command)
        } catch {
            print(error)
        }
    }
}

fileprivate extension NSColor {
    static var bestPink: NSColor {
        self.init(calibratedRed: 204 / 255, green: 51 / 255, blue: 139 / 255, alpha: 1)
    }
}

fileprivate extension ConnectionState {
    var description: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        }
    }
}
