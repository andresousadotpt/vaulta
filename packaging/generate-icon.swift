import AppKit

// Generates the Vaulta app icon: a rounded-square with an indigo→violet gradient
// and a white keyhole, matching the in-app BrandMark.

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let dimension: CGFloat = 1024
let size = NSSize(width: dimension, height: dimension)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)

// Background gradient on a rounded-rect (macOS "squircle"-ish radius).
let corner = dimension * 0.225
let bgPath = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
bgPath.addClip()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.36, green: 0.40, blue: 0.98, alpha: 1.0),
    NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.95, alpha: 1.0),
])
gradient?.draw(in: rect, angle: -45)

// Subtle top-to-bottom highlight across the whole face (no hard seam).
let highlight = NSGradient(colors: [
    NSColor(white: 1.0, alpha: 0.16),
    NSColor(white: 1.0, alpha: 0.0),
])
highlight?.draw(in: rect, angle: 90)

// Keyhole, centered.
let khWidth = dimension * 0.34
let khHeight = dimension * 0.42
let originX = (dimension - khWidth) / 2
let originY = (dimension - khHeight) / 2 - dimension * 0.02
let kh = NSRect(x: originX, y: originY, width: khWidth, height: khHeight)

let headDiameter = khWidth * 0.62
// AppKit's origin is bottom-left, so the round head sits at the TOP of the slot.
let headRect = NSRect(
    x: kh.midX - headDiameter / 2,
    y: kh.maxY - headDiameter,
    width: headDiameter,
    height: headDiameter
)

let path = NSBezierPath()
path.appendOval(in: headRect)

let slotTopY = headRect.minY + headDiameter * 0.18
let bottomY = kh.minY
let topHalf = khWidth * 0.12
let bottomHalf = khWidth * 0.26
path.move(to: NSPoint(x: kh.midX - topHalf, y: slotTopY))
path.line(to: NSPoint(x: kh.midX + topHalf, y: slotTopY))
path.line(to: NSPoint(x: kh.midX + bottomHalf, y: bottomY))
path.line(to: NSPoint(x: kh.midX - bottomHalf, y: bottomY))
path.close()

NSColor.white.setFill()
path.fill()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to generate icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
