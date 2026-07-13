import AppKit
import CoreImage

enum PixelateRenderer {
    private static let context = CIContext()

    static func pixelatedImage(from baseImage: NSImage, rect: NSRect, scale: CGFloat) -> NSImage? {
        guard rect.width > 0, rect.height > 0,
              let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let scaleX = CGFloat(cgImage.width) / baseImage.size.width
        let scaleY = CGFloat(cgImage.height) / baseImage.size.height
        let cropRect = CGRect(
            x: rect.minX * scaleX,
            y: (baseImage.size.height - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral.intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard !cropRect.isNull, !cropRect.isEmpty,
              let croppedCGImage = cgImage.cropping(to: cropRect),
              let filter = CIFilter(name: "CIPixellate") else { return nil }

        let ciImage = CIImage(cgImage: croppedCGImage)
        let extent = ciImage.extent
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(max(scale, Annotation.minimumPixelBlockScale), forKey: kCIInputScaleKey)
        filter.setValue(CIVector(x: extent.midX, y: extent.midY), forKey: kCIInputCenterKey)

        guard let outputImage = filter.outputImage?.cropped(to: extent),
              let outputCGImage = context.createCGImage(outputImage, from: extent) else { return nil }
        return NSImage(cgImage: outputCGImage, size: rect.size)
    }
}
