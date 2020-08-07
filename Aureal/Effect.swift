import Foundation

enum EffectType {
    case builtInEffect
    case direct
}

enum EffectColorMode: Equatable {
    case none
    case count(Int)
    case dynamic

    var count: Int {
        switch self {
        case .none:
            return 0
        case .count(let count):
            return count
        case .dynamic:
            return 3
        }
    }
}

protocol Effect {
    var name: String { get }
    var type: EffectType { get }
    var colorMode: EffectColorMode { get }

    func command(for colors: [CommandColor]) -> Command
}

struct BuiltInEffect: Effect {
    let mode: AuraEffect

    var name: String {
        "Built-in: \(mode.name)"
    }

    var colorMode: EffectColorMode {
        mode.isColorable ? .count(1) : .none
    }

    var type: EffectType {
        .builtInEffect
    }

    func command(for colors: [CommandColor]) -> Command {
        let command = EffectCommand(
            mode,
            color: mode.isColorable ? colors.first ?? .black : .black
        )

        return command
    }
}

struct DirectEffect: Effect {
    let name: String
    let builder: (([CommandColor]) -> DirectCommand)
    let colorMode: EffectColorMode

    var type: EffectType {
        .direct
    }

    func command(for colors: [CommandColor]) -> Command {
        return builder(colors)
    }
}
