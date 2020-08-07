import Cocoa

class GradientView: NSView {
    private var colors = [NSColor]()
    private var gradients = [Gradient]()

    override func draw(_ dirtyRect: NSRect) {
        let segmentWidth = (
            bounds.width / CGFloat(gradients.count)
        ).rounded(.awayFromZero)

        for (idx, gradient) in gradients.enumerated() {
            draw(
                gradient: gradient,
                in: NSRect(
                    x: CGFloat(idx) * segmentWidth,
                    y: 0,
                    width: segmentWidth,
                    height: bounds.height
                )
            )
        }
    }

    private func draw(gradient: Gradient, in rect: NSRect) {
        let count = Int(rect.width)

        let colors = gradient.colors(count)

        for (idx, color) in colors.enumerated() {
            color.nsColor.set()

            NSRect(
                x: rect.minX + CGFloat(idx),
                y: rect.minY,
                width: 1,
                height: rect.height
            ).fill()
        }
    }

    func update(with colors: [NSColor]) {
        self.colors = colors

        if colors.count == 0 {
            gradients = [StaticGradient(color: CommandColor.black)]
        } else if colors.count == 1 {
            gradients = [LRGBGradient(from: colors[0], to: colors[0])]
        } else if colors.count > 1 {
            var gx = [Gradient]()

            for idx in 0..<colors.count - 1 {
                let from = colors[idx]
                let to = colors[idx + 1]

                let next = LRGBGradient(from: from, to: to)
                gx.append(next)
            }

            gradients = gx
        }

        needsDisplay = true
    }
}

protocol Gradient {
    func colors(_ count: Int) -> [CommandColor]
}

struct StaticGradient: Gradient {
    let color: CommandColor

    init(color: CommandColor) {
        self.color = color
    }

    init(color: NSColor) {
        self.init(color: CommandColor(color: color))
    }

    func colors(_ count: Int) -> [CommandColor] {
        Array(repeating: color, count: count)
    }
}

struct LRGBGradient: Gradient {
    let from: CommandColor
    let to: CommandColor

    init(from: CommandColor, to: CommandColor) {
        self.from = from
        self.to = to
    }

    init(from: NSColor, to: NSColor) {
        self.from = CommandColor(color: from)
        self.to = CommandColor(color: to)
    }

    func colors(_ count: Int) -> [CommandColor] {
        (0..<count).map { idx in
            let percentage = Double(idx) / Double(count)

            let r = sqrt(pow(Double(from.r), 2) * (1 - percentage) + pow(Double(Int(to.r)), 2) * percentage)
            let g = sqrt(pow(Double(from.g), 2) * (1 - percentage) + pow(Double(Int(to.g)), 2) * percentage)
            let b = sqrt(pow(Double(from.b), 2) * (1 - percentage) + pow(Double(Int(to.b)), 2) * percentage)

            return CommandColor(
                r: UInt8(r),
                g: UInt8(g),
                b: UInt8(b)
            )
        }
    }
}

struct RGBGradient: Gradient {
    let from: CommandColor
    let to: CommandColor

    init(from: CommandColor, to: CommandColor) {
        self.from = from
        self.to = to
    }

    init(from: NSColor, to: NSColor) {
        self.from = CommandColor(color: from)
        self.to = CommandColor(color: to)
    }

    func colors(_ count: Int) -> [CommandColor] {
        (0..<count).map { idx in
            var percentage = (Double(idx) / Double(count))

            // this is a bouncing gradient, so returns back toward where it came
            if percentage > 1 {
                percentage = percentage.rounded(.awayFromZero) - percentage
            }

            let r = Double(from.r) + percentage * Double(Int(to.r) - Int(from.r))
            let g = Double(from.g) + percentage * Double(Int(to.g) - Int(from.g))
            let b = Double(from.b) + percentage * Double(Int(to.b) - Int(from.b))

            return CommandColor(
                r: UInt8(r),
                g: UInt8(g),
                b: UInt8(b)
            )
        }
    }
}

fileprivate extension CommandColor {
    var nsColor: NSColor {
        return NSColor(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}
