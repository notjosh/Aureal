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
        let rgb = color.usingColorSpace(NSColorSpace.sRGB)!
//        let rgb = color

        let r: UInt8 = UInt8(rgb.redComponent * 255)
        let g: UInt8 = UInt8(rgb.greenComponent * 255)
        let b: UInt8 = UInt8(rgb.blueComponent * 255)

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
    var isAnimated: Bool { get }
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

    var isAnimated: Bool {
        false
    }
}

struct StaticDirectCommand: DirectCommand {
    let color: CommandColor

    var isAnimated: Bool {
        false
    }

    init(color: CommandColor) {
        self.color = color
    }

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        return [color].repeated(capacity: capacity)
    }
}

struct SpacedDirectCommand: DirectCommand {
    let color: CommandColor

    var isAnimated: Bool {
        true
    }

    init(color: CommandColor) {
        self.color = color
    }

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        let step = step / 10

        let colors = [color, .black]
            .stretched(by: 2)

        return colors
            .wrap(first: step % colors.count)
            .repeated(capacity: capacity)
    }
}

class GradientDirectCommand: DirectCommand {
    let gradients: [RGBGradient]

    private let colors: [CommandColor]
    private let steps = 200

    var isAnimated: Bool {
        true
    }

    convenience init(from: CommandColor, to: CommandColor) {
        self.init(colors: [from, to, from])
    }

    convenience init(colors: [CommandColor]) {
        let gradients: [RGBGradient]
        if colors.count <= 0 {
            gradients = [RGBGradient(from: CommandColor.black, to: CommandColor.black)]
        } else if colors.count == 1 {
            gradients = [RGBGradient(from: colors[0], to: colors[0])]
        } else {
            var gx = [RGBGradient]()

            for idx in 0..<colors.count - 1 {
                let from = colors[idx]
                let to = colors[idx + 1]

                let next = RGBGradient(from: from, to: to)
                gx.append(next)
            }

            gradients = gx
        }

        self.init(gradients: gradients)
    }

    init(gradients: [RGBGradient]) {
        self.gradients = gradients

        var colors = [CommandColor]()
        for gradient in gradients {
            colors += gradient.colors(steps)
        }

        self.colors = colors
    }

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        let step = step % colors.count

        return (0..<capacity).map { idx in
            let offset = (idx * (steps / 10) - step) %% colors.count
            return colors[offset]
        }
    }
}

class RollingGradientDirectCommand: GradientDirectCommand {
    override init(gradients: [RGBGradient]) {
        guard gradients.count > 0 else {
            super.init(gradients: gradients)
            return
        }

        let wrap = RGBGradient(
            from: gradients.last!.to,
            to: gradients.first!.from
        )

        super.init(gradients: gradients + [wrap])
    }
}

struct Patriotism🦅DirectCommand: DirectCommand {
    let colors = [CommandColor.red, CommandColor.white, CommandColor.blue].stretched(by: 2)

    var isAnimated: Bool {
        true
    }

    func rgbs(capacity: Int, step: Int) -> [CommandColor] {
        let step = step / 10
        let out = colors
            .wrap(first: step % colors.count)
            .repeated(capacity: capacity)

        return Array(out)
    }
}

// essentially "%", but also works on negative numbers
// via https://stackoverflow.com/a/59461073
infix operator %%
extension Int {
    static func %% (_ left: Int, _ right: Int) -> Int {
        if left >= 0 { return left % right }
        if left >= -right { return (left + right) }
        return ((left % right) + right) % right
    }
}
