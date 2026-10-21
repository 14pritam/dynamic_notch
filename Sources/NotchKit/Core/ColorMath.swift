import Foundation

/// Picks a tint from album art for the Now Playing bars, the way iOS does.
public enum ColorMath {
    public struct RGB: Equatable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        public static let white = RGB(red: 1, green: 1, blue: 1)
    }

    /// Average of RGBA8 pixels weighted toward vivid colours, then lifted so it reads on black.
    /// Grey artwork falls back to white.
    public static func accent(fromRGBA pixels: [UInt8]) -> RGB {
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var totalWeight = 0.0
        var index = 0
        while index + 3 < pixels.count {
            let alpha = Double(pixels[index + 3]) / 255
            if alpha > 0.1 {
                let r = Double(pixels[index]) / 255 / alpha
                let g = Double(pixels[index + 1]) / 255 / alpha
                let b = Double(pixels[index + 2]) / 255 / alpha
                let (_, saturation, brightness) = hsb(RGB(red: min(r, 1), green: min(g, 1), blue: min(b, 1)))
                let weight = 0.05 + saturation * brightness
                red += min(r, 1) * weight
                green += min(g, 1) * weight
                blue += min(b, 1) * weight
                totalWeight += weight
            }
            index += 4
        }
        guard totalWeight > 0 else { return .white }
        let average = RGB(red: red / totalWeight, green: green / totalWeight, blue: blue / totalWeight)
        let (hue, saturation, _) = hsb(average)
        if saturation < 0.12 {
            return .white
        }
        return rgb(hue: hue, saturation: min(max(saturation, 0.45), 0.85), brightness: 0.95)
    }

    public static func hsb(_ color: RGB) -> (hue: Double, saturation: Double, brightness: Double) {
        let maximum = max(color.red, color.green, color.blue)
        let minimum = min(color.red, color.green, color.blue)
        let delta = maximum - minimum
        var hue = 0.0
        if delta > 0 {
            if maximum == color.red {
                hue = ((color.green - color.blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maximum == color.green {
                hue = (color.blue - color.red) / delta + 2
            } else {
                hue = (color.red - color.green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        let saturation = maximum == 0 ? 0 : delta / maximum
        return (hue, saturation, maximum)
    }

    public static func rgb(hue: Double, saturation: Double, brightness: Double) -> RGB {
        let h = (hue - floor(hue)) * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let (r, g, b): (Double, Double, Double) = switch Int(h) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        return RGB(red: r + m, green: g + m, blue: b + m)
    }
}
