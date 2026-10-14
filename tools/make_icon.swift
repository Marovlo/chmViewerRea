// make_icon.swift — generates the app icon PNG set (macOS squircle + bold "?")
import AppKit

func render(_ size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // vertical gradient (indigo -> deep blue), clipped to the squircle
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.32, green: 0.47, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.15, green: 0.22, blue: 0.72, alpha: 1)
    ])!
    gradient.draw(in: path, angle: -90)

    // white "CHM" centered, slight optical lift
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.28, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
        .kern: size * 0.015
    ]
    NSAttributedString(string: "CHM", attributes: attrs)
        .draw(in: NSRect(x: 0, y: size * 0.36, width: size, height: size * 0.3))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
let outDir = "build/AppIcon.iconset"
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in specs {
    let rep = render(px)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("wrote \(outDir)/\(name)")
}
