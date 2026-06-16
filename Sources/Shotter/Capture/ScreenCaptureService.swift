import AppKit
import CoreGraphics

struct ScreenSnapshot {
    let screenFrame: NSRect
    let cgImage: CGImage

    var image: NSImage {
        NSImage(cgImage: cgImage, size: screenFrame.size)
    }
}

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
    func captureScreens() throws -> [ScreenSnapshot] {
        try NSScreen.screens.map { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let cgImage = CGDisplayCreateImage(displayID.uint32Value) else {
                throw ScreenCaptureError.captureFailed
            }
            return ScreenSnapshot(screenFrame: screen.frame, cgImage: cgImage)
        }
    }

    func capture(rect appKitRect: NSRect) throws -> NSImage {
        let snapshots = try captureScreens()
        return try crop(rect: appKitRect, from: snapshots)
    }

    func crop(rect appKitRect: NSRect, from snapshots: [ScreenSnapshot]) throws -> NSImage {
        guard let snapshot = snapshots
            .filter({ $0.screenFrame.intersects(appKitRect) })
            .max(by: { $0.screenFrame.intersection(appKitRect).area < $1.screenFrame.intersection(appKitRect).area }) else {
            throw ScreenCaptureError.noDisplayForSelection
        }

        let clippedRect = appKitRect.intersection(snapshot.screenFrame)
        let cropRect = pixelCropRect(for: clippedRect, in: snapshot)
        guard let cgImage = snapshot.cgImage.cropping(to: cropRect) else {
            throw ScreenCaptureError.imageConversionFailed
        }

        return NSImage(cgImage: cgImage, size: clippedRect.size)
    }

    private func pixelCropRect(for appKitRect: NSRect, in snapshot: ScreenSnapshot) -> CGRect {
        let scaleX = CGFloat(snapshot.cgImage.width) / snapshot.screenFrame.width
        let scaleY = CGFloat(snapshot.cgImage.height) / snapshot.screenFrame.height
        let relativeX = appKitRect.minX - snapshot.screenFrame.minX
        let relativeY = appKitRect.minY - snapshot.screenFrame.minY
        let pixelRect = CGRect(
            x: relativeX * scaleX,
            y: (snapshot.screenFrame.height - relativeY - appKitRect.height) * scaleY,
            width: appKitRect.width * scaleX,
            height: appKitRect.height * scaleY
        ).integral
        return pixelRect.intersection(CGRect(x: 0, y: 0, width: snapshot.cgImage.width, height: snapshot.cgImage.height))
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
