import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// How much the saved JPEG may trade detail for size. Raw values are
/// persisted in user defaults, so they stay stable.
enum ImageQuality: String, CaseIterable {
    /// Highest JPEG quality: the closest to the original capture.
    case lossless
    /// Visually identical for UI, text and annotations at a fraction of the size.
    case high
    /// Smaller still; fine text and soft gradients may show artifacts when zoomed in.
    case compact

    static let `default`: ImageQuality = .high

    var title: String {
        switch self {
        case .lossless: return "Maximum (largest)"
        case .high: return "High (recommended)"
        case .compact: return "Compact (smallest)"
        }
    }

    /// `kCGImageDestinationLossyCompressionQuality`, from 0 (smallest) to 1 (best).
    var jpegCompressionQuality: Double {
        switch self {
        case .lossless: return 1.0
        case .high: return 0.9
        case .compact: return 0.75
        }
    }
}

enum ScreenshotEncoder {
    /// File extension matching `jpegData` output.
    static let fileExtension = "jpg"
    static let contentType = UTType.jpeg

    /// Encodes `image` as an opaque sRGB JPEG (any transparency composites onto white).
    /// `pointSize` sets the JPEG's DPI so Retina captures open at their on-screen size.
    static func jpegData(from image: CGImage, pointSize: CGSize? = nil, quality: ImageQuality) -> Data? {
        guard let pixels = RGBPixels(image: image), let opaque = pixels.makeTruecolorImage() else { return nil }
        var properties = dpiProperties(pixelWidth: image.width, pixelHeight: image.height, pointSize: pointSize)
        properties[kCGImageDestinationLossyCompressionQuality] = quality.jpegCompressionQuality
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, contentType.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, opaque, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func dpiProperties(pixelWidth: Int, pixelHeight: Int, pointSize: CGSize?) -> [CFString: Any] {
        guard let pointSize, pointSize.width > 0, pointSize.height > 0 else { return [:] }
        return [
            kCGImagePropertyDPIWidth: 72 * CGFloat(pixelWidth) / pointSize.width,
            kCGImagePropertyDPIHeight: 72 * CGFloat(pixelHeight) / pointSize.height
        ]
    }
}

/// Opaque 8-bit sRGB pixels, packed RGB (alpha dropped: screenshots are opaque,
/// and a fourth channel only costs bytes).
struct RGBPixels {
    let width: Int
    let height: Int
    /// `width * height * 3` bytes, rows top to bottom.
    let bytes: [UInt8]

    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    init(width: Int, height: Int, bytes: [UInt8]) {
        precondition(bytes.count == width * height * 3)
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init?(image: CGImage) {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var rgbx = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = rgbx.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: Self.colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            // Any transparency composites onto white, like a viewer would show it.
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var rgb = [UInt8](repeating: 0, count: width * height * 3)
        for pixel in 0..<(width * height) {
            rgb[pixel * 3] = rgbx[pixel * 4]
            rgb[pixel * 3 + 1] = rgbx[pixel * 4 + 1]
            rgb[pixel * 3 + 2] = rgbx[pixel * 4 + 2]
        }
        self.init(width: width, height: height, bytes: rgb)
    }

    func makeTruecolorImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: width * 3,
            space: Self.colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
