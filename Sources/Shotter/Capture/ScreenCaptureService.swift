import AppKit
import CoreGraphics

enum ScreenCaptureError: LocalizedError {
    case noDisplayForSelection
    case captureFailed
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .noDisplayForSelection:
            return "Could not find a display for the selected region."
        case .captureFailed:
            return "macOS did not return image data for the selected region."
        case .imageConversionFailed:
            return "The captured image could not be converted for editing."
        }
    }
}

final class ScreenCaptureService {
    func capture(rect appKitRect: NSRect) throws -> NSImage {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(appKitRect) }) else {
            throw ScreenCaptureError.noDisplayForSelection
        }

        let clippedRect = appKitRect.intersection(screen.frame)
        let captureRect = Geometry.cgCaptureRect(fromAppKitRect: clippedRect, in: screen)

        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            throw ScreenCaptureError.captureFailed
        }

        let scale = screen.backingScaleFactor
        let image = NSImage(cgImage: cgImage, size: NSSize(width: clippedRect.width, height: clippedRect.height))
        image.size = NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        return image
    }
}
