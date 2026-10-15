import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import OneShot

final class ScreenshotEncoderTests: XCTestCase {
    func testEncodesAsJPEGThatDecodesAtFullSize() throws {
        let source = Self.screenshotLikePixels(width: 240, height: 160)
        let data = try XCTUnwrap(ScreenshotEncoder.jpegData(from: try XCTUnwrap(source.makeTruecolorImage()), quality: .high))
        XCTAssertEqual(Array(data.prefix(3)), [0xFF, 0xD8, 0xFF], "JPEG SOI marker")
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(imageSource) as String?, UTType.jpeg.identifier)
        let decoded = try Self.decode(data)
        XCTAssertEqual(decoded.width, 240)
        XCTAssertEqual(decoded.height, 160)
    }

    func testSaveFormatIsJPG() {
        XCTAssertEqual(ScreenshotEncoder.fileExtension, "jpg")
        XCTAssertEqual(ScreenshotEncoder.contentType, .jpeg)
        XCTAssertEqual(UTType(filenameExtension: ScreenshotEncoder.fileExtension), .jpeg)
    }

    func testQualitiesTradeSizeForFidelity() throws {
        let source = Self.screenshotLikePixels(width: 480, height: 320)
        let image = try XCTUnwrap(source.makeTruecolorImage())
        let maximum = try XCTUnwrap(ScreenshotEncoder.jpegData(from: image, quality: .lossless))
        let high = try XCTUnwrap(ScreenshotEncoder.jpegData(from: image, quality: .high))
        let compact = try XCTUnwrap(ScreenshotEncoder.jpegData(from: image, quality: .compact))

        XCTAssertLessThan(high.count, maximum.count)
        XCTAssertLessThan(compact.count, high.count)
        XCTAssertGreaterThan(Self.psnr(source, try Self.decode(maximum)), 38)
        XCTAssertGreaterThan(Self.psnr(source, try Self.decode(high)), 32)
        XCTAssertGreaterThan(Self.psnr(source, try Self.decode(compact)), 28)
    }

    func testTransparencyCompositesOntoWhite() throws {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
            space: RGBPixels.colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let transparent = try XCTUnwrap(context.makeImage())
        let data = try XCTUnwrap(ScreenshotEncoder.jpegData(from: transparent, quality: .high))
        XCTAssertTrue(try Self.decode(data).bytes.allSatisfy { $0 >= 250 })
    }

    func testRetinaCapturesRecordTheirPointSize() throws {
        let source = Self.screenshotLikePixels(width: 200, height: 100)
        let data = try XCTUnwrap(ScreenshotEncoder.jpegData(
            from: try XCTUnwrap(source.makeTruecolorImage()),
            pointSize: CGSize(width: 100, height: 50),
            quality: .high
        ))
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any])
        XCTAssertEqual((properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 0, 144, accuracy: 0.5)
    }

    func testRendererKeepsTheCapturePixelSize() throws {
        // A 1x capture must not be upscaled to the main screen's scale.
        let pixels = try XCTUnwrap(Self.screenshotLikePixels(width: 120, height: 80).makeTruecolorImage())
        let baseImage = NSImage(cgImage: pixels, size: NSSize(width: 120, height: 80))
        let rendered = try XCTUnwrap(ImageRenderer.render(baseImage: baseImage, annotations: []))
        XCTAssertEqual(rendered.width, 120)
        XCTAssertEqual(rendered.height, 80)

        let retina = NSImage(cgImage: pixels, size: NSSize(width: 60, height: 40))
        let renderedRetina = try XCTUnwrap(ImageRenderer.render(baseImage: retina, annotations: []))
        XCTAssertEqual(renderedRetina.width, 120)
        XCTAssertEqual(renderedRetina.height, 80)
    }

    func testQualitySettingDefaultsToHighAndPersists() throws {
        let suiteName = "ScreenshotEncoderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(ImageQualitySettings.quality(in: defaults), .high)
        ImageQualitySettings.setQuality(.lossless, in: defaults)
        XCTAssertEqual(ImageQualitySettings.quality(in: defaults), .lossless)
        defaults.set("bogus", forKey: ImageQualitySettings.key)
        XCTAssertEqual(ImageQualitySettings.quality(in: defaults), .high)
    }

    // MARK: - Helpers

    /// Deterministic stand-in for a screenshot: a soft photo-like gradient
    /// with mild texture, a flat toolbar strip and a few hard-edged blocks.
    private static func screenshotLikePixels(width: Int, height: Int) -> RGBPixels {
        var bytes = [UInt8](repeating: 0, count: width * height * 3)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 3
                if y < height / 8 {
                    bytes[i] = 236; bytes[i + 1] = 236; bytes[i + 2] = 236
                    continue
                }
                let texture = Double((x &* 7919 ^ y &* 104_729) % 9) - 4
                let fx = Double(x) / Double(width), fy = Double(y) / Double(height)
                bytes[i] = UInt8(clamping: Int(70 + 120 * fx + texture))
                bytes[i + 1] = UInt8(clamping: Int(140 + 80 * fy + texture))
                bytes[i + 2] = UInt8(clamping: Int(230 - 60 * fx * fy + texture))
                if (x / 40 + y / 40) % 5 == 0 {
                    bytes[i] = 20; bytes[i + 1] = 20; bytes[i + 2] = 24
                }
            }
        }
        return RGBPixels(width: width, height: height, bytes: bytes)
    }

    private static func decode(_ data: Data) throws -> RGBPixels {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return try XCTUnwrap(RGBPixels(image: image))
    }

    private static func psnr(_ lhs: RGBPixels, _ rhs: RGBPixels) -> Double {
        var squaredError = 0.0
        for index in lhs.bytes.indices {
            let delta = Double(lhs.bytes[index]) - Double(rhs.bytes[index])
            squaredError += delta * delta
        }
        let meanSquaredError = squaredError / Double(lhs.bytes.count)
        return meanSquaredError == 0 ? .infinity : 10 * log10(255 * 255 / meanSquaredError)
    }
}
