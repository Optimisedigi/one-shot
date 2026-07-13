import AppKit
import UniformTypeIdentifiers

extension NSPasteboard.PasteboardType {
    static let png = NSPasteboard.PasteboardType("public.png")
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([self])
        if let pngData = pngData() {
            pasteboard.setData(pngData, forType: .png)
        }
    }

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
