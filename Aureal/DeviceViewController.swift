import Cocoa
import Combine

class DeviceViewModel {
    private let device: AuraUSBDevice

    let connectionState: AnyPublisher<AuraDeviceConnectionState, Never>

    init(device: AuraUSBDevice) {
        self.device = device

        print(device)

        connectionState = device.$connectionState.eraseToAnyPublisher()
    }
}

class DeviceViewController: NSViewController {
    @IBOutlet private var connectedStatusLabel: NSTextField!
    @IBOutlet private var effectsPopUpButton: NSPopUpButton!
    @IBOutlet private var colorWell: NSColorWell!

    private var cancellableSet: Set<AnyCancellable> = []

    var viewModel: DeviceViewModel!
    var runEffect: ((Command) -> Void)?

    private var currentEffect: Effect!
    private var currentColor = NSColor.bestPink

    private var effects = [Effect]()

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.connectionState
            .receive(on: DispatchQueue.main)
            .map { $0.description }
            .assign(to: \.stringValue, on: connectedStatusLabel)
            .store(in: &cancellableSet)

        // set up effects list
        effects = [DirectEffect()] + AuraEffect.allCases.map { BuiltInEffect(mode: $0) }

        effectsPopUpButton.removeAllItems()
        for effect in effects {
            effectsPopUpButton.addItem(withTitle: effect.name)
        }

        // set defaults
        currentEffect = effects.first!
        effectsPopUpButton.selectItem(at: 0)
        colorWell.color = currentColor
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
//            command = StaticSpacedDirectCommand(color: commandColor)
            command = GradientDirectCommand(fromColor: commandColor)
//            command = PlaygroundDirectCommand()
//        command = StaticDirectCommand(color: commandColor)
        }

//        print(command)
//        send(command)

        runEffect?(command)
    }
}

fileprivate extension NSColor {
    static var bestPink: NSColor {
        self.init(calibratedRed: 216 / 255, green: 4 / 255, blue: 155 / 255, alpha: 1)
    }
}

fileprivate extension AuraDeviceConnectionState {
    var description: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        }
    }
}
