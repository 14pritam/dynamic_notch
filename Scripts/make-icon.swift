// Renders Support/AppIcon.icns. Run from the repository root:
//   swift Scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Draws the icon on a 1024-point canvas (Big Sur grid: 824 pt body, 100 pt margins).
func draw(in context: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the tile.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    context.addPath(squircle)
    context.setFillColor(color(0x1B1C22))
    context.fillPath()
    context.restoreGState()

    // Night-sky gradient.
    context.saveGState()
    context.addPath(squircle)
    context.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x434658), color(0x24252F), color(0x101116)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Soft glow behind the pill.
    let glow = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0xFF7A45, 0.35), color(0xFF7A45, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 560), startRadius: 0, endCenter: CGPoint(x: 512, y: 560), endRadius: 420, options: [])

    // The notch, hanging from the top edge.
    let notch = CGPath(roundedRect: CGRect(x: 357, y: 820, width: 310, height: 150), cornerWidth: 46, cornerHeight: 46, transform: nil)
    context.addPath(notch)
    context.setFillColor(color(0x000000))
    context.fillPath()
    context.restoreGState()

    // The pill.
    let pill = CGRect(x: 192, y: 470, width: 640, height: 196)
    let pillPath = CGPath(roundedRect: pill, cornerWidth: 98, cornerHeight: 98, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: color(0x000000, 0.6))
    context.addPath(pillPath)
    context.setFillColor(color(0x000000))
    context.fillPath()
    context.restoreGState()

    // Subtle rim light on the pill's top edge.
    context.saveGState()
    context.addPath(pillPath)
    context.setStrokeColor(color(0xFFFFFF, 0.10))
    context.setLineWidth(3)
    context.strokePath()
    context.restoreGState()

    let warm = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0xFFB340), color(0xFF4F7B)] as CFArray,
        locations: [0, 1]
    )!

    // Album art.
    let art = CGRect(x: 246, y: 514, width: 108, height: 108)
    context.saveGState()
    context.addPath(CGPath(roundedRect: art, cornerWidth: 28, cornerHeight: 28, transform: nil))
    context.clip()
    context.drawLinearGradient(warm, start: CGPoint(x: art.minX, y: art.maxY), end: CGPoint(x: art.maxX, y: art.minY), options: [])
    context.restoreGState()

    // Waveform bars.
    let heights: [CGFloat] = [56, 104, 76, 120, 64]
    let barWidth: CGFloat = 20
    let spacing: CGFloat = 14
    let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * spacing
    var x = 778 - totalWidth
    for height in heights {
        let bar = CGRect(x: x, y: pill.midY - height / 2, width: barWidth, height: height)
        context.saveGState()
        context.addPath(CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        context.clip()
        context.drawLinearGradient(warm, start: CGPoint(x: bar.minX, y: bar.maxY), end: CGPoint(x: bar.maxX, y: bar.minY), options: [])
        context.restoreGState()
        x += barWidth + spacing
    }
}

func render(pixels: Int) throws -> Data {
    let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    draw(in: context)
    let image = context.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(pixels: 1024).write(to: root.appendingPathComponent("Support/AppIcon-1024.png"))

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Support/AppIcon.icns").path]
try process.run()
process.waitUntilExit()
print(process.terminationStatus == 0 ? "Wrote Support/AppIcon.icns" : "iconutil failed")
