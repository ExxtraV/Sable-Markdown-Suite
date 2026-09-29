// Fits the Sable icon master onto the macOS icon grid and writes every iconset size.
// Usage: swift scripts/render-icon.swift <master-1024.png> <small-mark.png> <output.iconset>
//
// Large sizes: the master tile sits in an 824-point body inside the 1024 canvas (100-point margin), clipped to
// Apple's continuous-corner shape, with the standard soft drop shadow, so it lines up with other Dock icons.
// Small sizes (64 pixels and under): the tile fills most of the canvas and carries the simplified black-and-white
// mark, larger and without the gray throat patch, because the detailed mark turns to mush there.
import AppKit
import SwiftUI

let args = CommandLine.arguments
guard args.count == 4 else { FileHandle.standardError.write(Data("usage: render-icon.swift master.png small-mark.png out.iconset\n".utf8)); exit(2) }

func load(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        FileHandle.standardError.write(Data("Can't read \(path)\n".utf8)); exit(1)
    }
    return image
}

let master = load(args[1]), smallMark = load(args[2])
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue

func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: 4)
    let context = CGContext(data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: bitmap)!
    context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
    return data
}

// The tile's flat background color, sampled just inside the top edge of the body, and whether the tile is the dark one.
let background = pixel(master, x: master.width / 2, y: 90)
let darkTile = Int(background[0]) + Int(background[1]) + Int(background[2]) < 3 * 128

// The small mark is black on transparent; the dark tile needs it reversed. Inverting keeps the shape and edges
// (for premultiplied pixels, the inverse of a channel is alpha minus it).
func reversed(_ image: CGImage) -> CGImage {
    let width = image.width, height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmap)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    for i in stride(from: 0, to: data.count, by: 4) { for c in 0..<3 { data[i + c] = data[i + 3] - data[i + c] } }
    return context.makeImage()!
}
let mark = darkTile ? reversed(smallMark) : smallMark

// The visible bounds of the small mark, so it can be centered by what you see rather than by its canvas.
func opaqueBounds(_ image: CGImage) -> CGRect {
    let width = image.width, height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmap)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var minX = width, minY = height, maxX = 0, maxY = 0
    for y in 0..<height { for x in 0..<width where data[(y * width + x) * 4 + 3] > 128 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } }
    return CGRect(x: minX, y: height - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)   // bottom-left origin
}
let markBounds = opaqueBounds(mark)

// The corner factor was matched against the system's own Notes icon: its outline agrees to within a few pixels at 1024.
func bodyPath(in rect: CGRect) -> CGPath {
    RoundedRectangle(cornerRadius: rect.width * 0.26, style: .continuous).path(in: rect).cgPath
}

func render(pixels size: Int) -> CGImage {
    let side = CGFloat(size)
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmap)!
    context.interpolationQuality = .high
    context.setShouldAntialias(true)
    if size >= 128 {
        let body = CGRect(x: side * 100 / 1024, y: side * 100 / 1024, width: side * 824 / 1024, height: side * 824 / 1024)
        // Draw the master's own tile (its background and full mark), trimmed to the standard shape.
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -side * 10 / 1024), blur: side * 24 / 1024, color: CGColor(gray: 0, alpha: 0.30))
        context.addPath(bodyPath(in: body)); context.setFillColor(CGColor(srgbRed: CGFloat(background[0]) / 255, green: CGFloat(background[1]) / 255, blue: CGFloat(background[2]) / 255, alpha: 1)); context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(bodyPath(in: body)); context.clip()
        // The master's tile is 944 points wide inside its 1024 canvas, starting 40 points in.
        let scale = body.width / 944
        context.draw(master, in: CGRect(x: body.minX - 40 * scale, y: body.minY - 40 * scale, width: 1024 * scale, height: 1024 * scale))
        context.restoreGState()
    } else {
        let inset = side * 0.03
        let body = CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
        context.saveGState()
        context.addPath(bodyPath(in: body)); context.setFillColor(CGColor(srgbRed: CGFloat(background[0]) / 255, green: CGFloat(background[1]) / 255, blue: CGFloat(background[2]) / 255, alpha: 1)); context.fillPath()
        context.restoreGState()
        // The simplified mark, about 78% of the tile's width, centered on what it shows.
        let markWidth = body.width * 0.78, scale = markWidth / markBounds.width
        let drawn = CGSize(width: CGFloat(mark.width) * scale, height: CGFloat(mark.height) * scale)
        let origin = CGPoint(x: body.midX - markBounds.midX * scale, y: body.midY - markBounds.midY * scale)
        context.draw(mark, in: CGRect(origin: origin, size: drawn))
        // A hairline so a pale tile still reads against a white Finder window.
        context.addPath(bodyPath(in: body.insetBy(dx: 0.25, dy: 0.25)))
        context.setStrokeColor(CGColor(gray: darkTile ? 1 : 0, alpha: darkTile ? 0.18 : 0.22)); context.setLineWidth(max(0.5, side / 64)); context.strokePath()
    }
    return context.makeImage()!
}

try? FileManager.default.createDirectory(atPath: args[3], withIntermediateDirectories: true)
let files: [(String, Int)] = [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256),
                              ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)]
for (name, size) in files {
    let representation = NSBitmapImageRep(cgImage: render(pixels: size))
    try! representation.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(args[3])/\(name).png"))
}
print("Rendered \(files.count) icon sizes (\(darkTile ? "dark" : "light") tile) into \(args[3])")
