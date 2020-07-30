import Cocoa

struct CommandColor {
    let r: UInt8
    let g: UInt8
    let b: UInt8

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(color: NSColor) {
        let r: UInt8 = UInt8(color.redComponent * 255)
        let g: UInt8 = UInt8(color.greenComponent * 255)
        let b: UInt8 = UInt8(color.blueComponent * 255)

        self.init(r: r, g: g, b: b)
    }
    
    static let red = CommandColor(r: 0xff, g: 0x00, b: 0x00)
    static let blue = CommandColor(r: 0x00, g: 0x00, b: 0xff)
    static let green = CommandColor(r: 0x00, g: 0xff, b: 0x00)
    static let white = CommandColor(r: 0xff, g: 0xff, b: 0xff)
    static let lwhite = CommandColor(r: 0x40, g: 0x40, b: 0x40)
    static let black = CommandColor(r: 0x00, g: 0x00, b: 0x00)

    static var random: CommandColor {
        CommandColor(
            r: UInt8.random(in: 0...255),
            g: UInt8.random(in: 0...255),
            b: UInt8.random(in: 0...255)
        )
    }
}

protocol Command {
}

protocol DirectCommand: Command {
    func rgbs(capacity: Int, step: Int) -> [CommandColor]
}

struct EffectCommand: Command {
    let effect: AuraEffect
    let color: CommandColor

    let controlMode = AuraControlMode.effect

    init(_ effect: AuraEffect, color: CommandColor) {
        self.effect = effect
        self.color = color
    }
}

struct StaticDirectCommand: DirectCommand {
    let color: CommandColor

    init(color: CommandColor) {
        self.color = color
    }

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        return [color].repeated(capacity: capacity)
    }
}

struct StaticSpacedDirectCommand: DirectCommand {
    let color: CommandColor

    init(color: CommandColor) {
        self.color = color
    }

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        let colors = [color, .black]
            .stretched(by: 2)

        return colors
            .wrap(first: step % colors.count)
            .repeated(capacity: capacity)
    }
}

struct GradientDirectCommand: DirectCommand {
    let fromColor: CommandColor
    let toColor: CommandColor

    init(fromColor: CommandColor, toColor: CommandColor = .blue) {
        self.fromColor = fromColor
        self.toColor = toColor
    }

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        (0..<capacity).map { idx in
            // seems my front case has "120" reported leds, but 10 on top of case, and 14 in front panel irl. hm.
            let percentange = min(Double(idx) / Double(16), 1)
//            let percentange = Double(idx % 4) / Double(4)

            let r = Int(fromColor.r) + Int(Double(Int(toColor.r) - Int(fromColor.r)) * percentange)
            let g = Int(fromColor.g) + Int(Double(Int(toColor.g) - Int(fromColor.g)) * percentange)
            let b = Int(fromColor.b) + Int(Double(Int(toColor.b) - Int(fromColor.b)) * percentange)

            return CommandColor(
                r: UInt8(r),
                g: UInt8(g),
                b: UInt8(b)
            )
        }
    }
}

struct PlaygroundDirectCommand2: DirectCommand {
    let colors = [CommandColor.red, CommandColor.white, CommandColor.blue].stretched(by: 2)

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        let out = colors
            .wrap(first: step % colors.count)
            .repeated(capacity: capacity)

        return Array(out)
    }
}

struct PlaygroundDirectCommand: DirectCommand {
    let colors = [CommandColor.red, CommandColor.white, CommandColor.blue].stretched(by: 2)

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        guard capacity != 8 else {
            return [.white].repeated(capacity: capacity)
        }

        var out = [CommandColor.red].repeated(capacity: capacity)

        out[step % out.count] = .white

        return Array(out)
    }
}
