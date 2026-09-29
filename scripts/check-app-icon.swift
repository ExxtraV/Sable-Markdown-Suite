// Checks that Assets/Sable.icns follows the macOS icon grid, so Sable sits at the same size as other Dock icons.
// Large renditions: an 824-of-1024 rounded body centered in the canvas, transparent corners, room for a shadow.
// Small renditions (64 pixels and under): the body fills nearly the whole canvas and the mark still has contrast.
// Run from the repository root: swiftc scripts/check-app-icon.swift -o /tmp/quill-app-icon-checks && /tmp/quill-app-icon-checks
import Foundation
import CoreGraphics
import ImageIO

func fail(_ message: String) -> Never { print("FAILED: \(message)"); exit(1) }

struct Bitmap {
    let width: Int, height: Int, data: [UInt8]
    init(_ image: CGImage) {
        width = image.width; height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = bytes
    }
    func alpha(_ x: Int, _ y: Int) -> Int { Int(data[(y * width + x) * 4 + 3]) }
    func luminance(_ x: Int, _ y: Int) -> Int { let i = (y * width + x) * 4; return (Int(data[i]) + Int(data[i + 1]) + Int(data[i + 2])) / 3 }
    /// Bounds of the solid pixels, so a soft shadow doesn't count as body. Small icons have no shadow, and their
    /// antialiased edge pixels are only partly covered, so they count from half coverage.
    var body: (minX: Int, minY: Int, maxX: Int, maxY: Int) {
        var box = (minX: width, minY: height, maxX: 0, maxY: 0)
        let solid = width >= 128 ? 250 : 128
        for y in 0..<height { for x in 0..<width where alpha(x, y) > solid { box.minX = min(box.minX, x); box.maxX = max(box.maxX, x); box.minY = min(box.minY, y); box.maxY = max(box.maxY, y) } }
        return box
    }
}

let path = "Assets/Sable.icns"
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { fail("Can't open \(path)") }
var sizes = Set<Int>()
for index in 0..<CGImageSourceGetCount(source) {
    guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { fail("Rendition \(index) doesn't decode") }
    precondition(image.width == image.height, "Rendition \(index) isn't square")
    let size = image.width
    sizes.insert(size)
    let bitmap = Bitmap(image)
    let box = bitmap.body
    let fill = Double(box.maxX - box.minX + 1) / Double(size)
    let centerX = Double(box.minX + box.maxX + 1) / 2 / Double(size), centerY = Double(box.minY + box.maxY + 1) / 2 / Double(size)
    if size >= 128 {
        if abs(fill - 824.0 / 1024) > 0.012 { fail("\(size)px: body is \(fill * 100)% of the canvas, expected 80.5%") }
        if abs(centerX - 0.5) > 0.01 || abs(centerY - 0.5) > 0.01 { fail("\(size)px: body is off-center (\(centerX), \(centerY))") }
    } else {
        if fill < 0.88 { fail("\(size)px: small icons should fill the canvas, this fills \(fill * 100)%") }
    }
    // Rounded corners: the canvas corner and the body's own corner are clear, and the middle of each edge is solid.
    if bitmap.alpha(0, 0) != 0 || bitmap.alpha(size - 1, size - 1) != 0 { fail("\(size)px: canvas corner isn't transparent") }
    if bitmap.alpha(box.minX, box.minY) > 128 || bitmap.alpha(box.maxX, box.maxY) > 128 { fail("\(size)px: the body has square corners") }
    if bitmap.alpha((box.minX + box.maxX) / 2, box.minY + 1) < 250 { fail("\(size)px: top edge isn't solid") }
    // The mark has to stand out from the tile: some pixels well away from the tile color inside the body.
    let tile = bitmap.luminance((box.minX + box.maxX) / 2, box.minY + max(2, size / 40))
    var contrast = 0
    for y in box.minY..<box.maxY { for x in box.minX..<box.maxX where bitmap.alpha(x, y) > 250 && abs(bitmap.luminance(x, y) - tile) > 100 { contrast += 1 } }
    let share = Double(contrast) / Double((box.maxX - box.minX) * (box.maxY - box.minY))
    if share < 0.15 { fail("\(size)px: the mark is only \(Int(share * 100))% of the tile, too faint to read") }
}
for needed in [16, 32, 64, 128, 256, 512, 1024] where !sizes.contains(needed) { fail("Missing the \(needed)px rendition") }

// The master the icon is built from is a square 1024 tile.
guard let masterSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: "Assets/sable-icon-light-1024.png") as CFURL, nil),
      let master = CGImageSourceCreateImageAtIndex(masterSource, 0, nil) else { fail("Can't open the icon master") }
if master.width != 1024 || master.height != 1024 { fail("The icon master should be 1024x1024, not \(master.width)x\(master.height)") }
print("Passed: Sable.icns has every size, follows the macOS grid (824-of-1024 body, rounded, centered), fills the canvas at small sizes, and keeps the mark readable.")
