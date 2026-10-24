import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3 else { fatalError("Usage: video-label.swift OUTPUT TEXT") }
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1280, pixelsHigh: 64,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.black.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1280, height: 64)).fill()
(arguments[2] as NSString).draw(
    in: NSRect(x: 20, y: 16, width: 1240, height: 32),
    withAttributes: [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor.white]
)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: arguments[1]))
