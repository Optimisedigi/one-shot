import AppKit
import UniformTypeIdentifiers

extension NSImage {
    func cropped(to rect: NSRect) -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let scaleX = CGFloat(cgImage.width) / size.width
        let scaleY = CGFloat(cgImage.height) / size.height
        let cgRect = CGRect(
            x: rect.minX * scaleX,
            y: (size.height - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral
        guard let cropped = cgImage.cropping(to: cgRect) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }
}
