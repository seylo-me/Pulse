import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct GenerateBrandAssets {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            throw NSError(domain: "Pulse.Brand", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Expected resources and work directories"])
        }
        let resources = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let work = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let iconset = work.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

        // Render each representation separately, including proper Retina names.
        for points in [16, 32, 128, 256, 512] {
            for density in [1, 2] {
                let name = "icon_\(points)x\(points)" + (density == 2 ? "@2x" : "") + ".png"
                try writeIcon(pixels: points * density, to: iconset.appendingPathComponent(name))
            }
        }
        try writeIcon(pixels: 1024, to: resources.appendingPathComponent("AppIcon.png"))
        // Preserve the existing preview filename used by the original generator.
        let preview = try Data(contentsOf: resources.appendingPathComponent("AppIcon.png"))
        try preview.write(to: resources.appendingPathComponent("pulse_icon_1024.png"), options: .atomic)
        try writeSVG(to: resources.appendingPathComponent("PulseMark.svg"))
    }

    static func writeIcon(pixels: Int, to url: URL) throws {
        // Supersampling keeps the small dots and transparent rounded edges smooth.
        let renderSize = max(1024, pixels * 2)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: renderSize, height: renderSize,
                                      bitsPerComponent: 8, bytesPerRow: renderSize * 4,
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "Pulse.Brand", code: 2)
        }
        // Figma coordinates start at the top left; Core Graphics starts at the bottom left.
        context.translateBy(x: 0, y: CGFloat(renderSize))
        context.scaleBy(x: CGFloat(renderSize) / 1024, y: -CGFloat(renderSize) / 1024)
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        let base = CGRect(x: 100, y: 100, width: 824, height: 824)
        let basePath = CGPath(roundedRect: base, cornerWidth: 184, cornerHeight: 184, transform: nil)
        context.addPath(basePath)
        context.setFillColor(CGColor(srgbRed: 16 / 255, green: 17 / 255, blue: 19 / 255, alpha: 1))
        context.fillPath()
        context.addPath(CGPath(roundedRect: base.insetBy(dx: 0.5, dy: 0.5),
                               cornerWidth: 183.5, cornerHeight: 183.5, transform: nil))
        context.setStrokeColor(CGColor(srgbRed: 39 / 255, green: 41 / 255, blue: 45 / 255, alpha: 1))
        context.setLineWidth(1)
        context.strokePath()

        for dot in PulseBrandGeometry.dots {
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: dot.opacity))
            context.fillEllipse(in: PulseBrandGeometry.appRect(for: dot))
        }
        guard let rendered = context.makeImage() else {
            throw NSError(domain: "Pulse.Brand", code: 3)
        }
        let image: CGImage
        if pixels == renderSize {
            image = rendered
        } else {
            guard let scaled = CGContext(data: nil, width: pixels, height: pixels,
                                         bitsPerComponent: 8, bytesPerRow: pixels * 4, space: space,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw NSError(domain: "Pulse.Brand", code: 4)
            }
            scaled.interpolationQuality = .high
            scaled.draw(rendered, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
            guard let result = scaled.makeImage() else {
                throw NSError(domain: "Pulse.Brand", code: 5)
            }
            image = result
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "Pulse.Brand", code: 6)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "Pulse.Brand", code: 7)
        }
    }

    static func writeSVG(to url: URL) throws {
        let bounds = PulseBrandGeometry.bounds
        let circles = PulseBrandGeometry.dots.map { dot in
            "<circle cx=\"\(dot.rect.midX)\" cy=\"\(dot.rect.midY)\" r=\"\(dot.diameter / 2)\" fill=\"white\" opacity=\"\(dot.opacity)\"/>"
        }.joined(separator: "\n")
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(bounds.width)" height="\(bounds.height)" viewBox="\(bounds.minX) \(bounds.minY) \(bounds.width) \(bounds.height)">
        \(circles)
        </svg>
        """
        try svg.write(to: url, atomically: true, encoding: .utf8)
    }
}
