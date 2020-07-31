import Cocoa

enum EffectType {
    case builtInEffect
    case direct
}

enum EffectColorMode {
    case none
    case single
}

protocol Effect {
    var name: String { get }
    var type: EffectType { get }
    var colorMode: EffectColorMode { get }
}

struct BuiltInEffect: Effect {
    let mode: AuraEffect

    var name: String {
        "Built-in: \(mode.name)"
    }

    var colorMode: EffectColorMode {
        mode.isColorable ? .single : .none
    }

    var type: EffectType {
        .builtInEffect
    }
}

struct DirectEffect: Effect {
    var name: String {
        "Direct"
    }

    var colorMode: EffectColorMode {
        .single
    }

    var type: EffectType {
        .direct
    }
}

class ViewController: NSViewController {
    @IBOutlet private var connectedStatusLabel: NSTextField!
    @IBOutlet private var effectsPopUpButton: NSPopUpButton!
    @IBOutlet private var colorWell: NSColorWell!

    private var currentEffect: Effect!
    private var currentColor = NSColor.bestPink

    private var effects = [Effect]()

    private var connectionState: ConnectionState {
        AppDelegate.shared.controller?.connectionState ?? .disconnected
    }

    private var observation: Any? = nil
    private var activity: NSObjectProtocol?
    private var timer: Timer?

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
        timer = nil
        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // set up effects list
        effects = [DirectEffect()] + AuraEffect.allCases.map { BuiltInEffect(mode: $0) }

        // set up UI
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
        for effect in effects {
            effectsPopUpButton.addItem(withTitle: effect.name)
        }

        // set defaults
        currentEffect = effects.first!
        effectsPopUpButton.selectItem(at: 0)
        colorWell.color = currentColor
        updateConnectionState()

        let interval: TimeInterval = 0.1
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
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

    @IBAction func handleColor(sender: Any) {
        currentColor = colorWell.color

        update()
    }

    @IBAction func handleEffect(sender: Any) {
        let idx = effectsPopUpButton.indexOfSelectedItem

        guard
            idx >= 0,
            idx < effects.count
            else {
                return
        }

        currentEffect = effects[idx]

        colorWell.isHidden = currentEffect.colorMode == .none

        update()
    }

    private func update() {
        let commandColor = CommandColor(color: currentColor)
        let command: Command

        switch currentEffect.type {
        case .builtInEffect:
            let effect = currentEffect as! BuiltInEffect
            command = EffectCommand(
                effect.mode,
                color: effect.mode.isColorable ? commandColor : .black
            )
        case .direct:
            command = StaticSpacedDirectCommand(color: commandColor)
//            command = GradientDirectCommand(fromColor: commandColor)
//            command = PlaygroundDirectCommand()
        }

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
        self.init(calibratedRed: 216 / 255, green: 4 / 255, blue: 155 / 255, alpha: 1)
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
