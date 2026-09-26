import AppKit

enum PixelateRenderer {

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
              let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }

        // Downscale to a handful of samples, then blow those samples back up
        // with nearest-neighbor so each block is one flat color. CIPixellate
        // leaves pale gaps between blocks, which reads as a zoomed crop rather
        // than something being hidden.
        let devicePixelScale = max(scaleX, scaleY, 1)
        let block = max(scale, Annotation.minimumPixelBlockScale) * devicePixelScale
        let columns = max(1, Int((cropRect.width / block).rounded(.down)))
        let rows = max(1, Int((cropRect.height / block).rounded(.down)))
        guard let tiny = resample(croppedCGImage, width: columns, height: rows, interpolate: false),
              let mosaic = resample(tiny, width: croppedCGImage.width, height: croppedCGImage.height, interpolate: false) else { return nil }
        return NSImage(cgImage: mosaic, size: rect.size)
    }

    private static func resample(_ image: CGImage, width: Int, height: Int, interpolate: Bool) -> CGImage? {
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.interpolationQuality = interpolate ? .high : .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
