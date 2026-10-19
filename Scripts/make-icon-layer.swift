// Crops an icon picture to its own rounded square and scales it to a full-bleed
// 1024-pixel layer for Icon Composer, which applies the macOS shape itself:
//
//   swift Scripts/make-icon-layer.swift picture.png Resources/AppIcon.icon/Assets/Artwork.png
import AppKit
let input = CommandLine.arguments[1], output = CommandLine.arguments[2]
let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: input)))!
let image = rep.cgImage!
var minX = image.width, minY = image.height, maxX = 0, maxY = 0
for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } }
// A square inside the shape's box, trimmed a little so its glossy rim falls under the system's mask.
let side = CGFloat(min(maxX - minX, maxY - minY)) * 0.97
let center = CGPoint(x: CGFloat(minX + maxX) / 2, y: CGFloat(minY + maxY) / 2)
let crop = image.cropping(to: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side))!
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high
ctx.draw(crop, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("==> \(output) from box \(minX),\(minY)-\(maxX),\(maxY)")
