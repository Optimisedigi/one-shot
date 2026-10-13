import AppKit
import ImageIO
import XCTest
@testable import OneShot

final class ScreenshotEncoderTests: XCTestCase {
    func testLosslessRoundTripsEveryPixel() throws {
        let source = Self.screenshotLikePixels(width: 240, height: 160)
        let data = try XCTUnwrap(ScreenshotEncoder.pngData(from: try XCTUnwrap(source.makeTruecolorImage()), quality: .lossless))
        XCTAssertEqual(try Self.decode(data).bytes, source.bytes)
    }

    func testFewColorsAreStoredExactlyAsPalette() throws {
        // Flat UI: 4 colors, so even the palette qualities must be lossless.
        let colors: [[UInt8]] = [[30, 30, 30], [255, 59, 48], [255, 255, 255], [10, 132, 255]]
        let width = 64, height = 48
        var bytes: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width { bytes += colors[(x / 16 + y / 12) % colors.count] }
        }
        let source = RGBPixels(width: width, height: height, bytes: bytes)

        for quality in [ImageQuality.high, .compact] {
            let data = try XCTUnwrap(ScreenshotEncoder.pngData(from: try XCTUnwrap(source.makeTruecolorImage()), quality: quality))
            XCTAssertEqual(try Self.decode(data).bytes, source.bytes, "\(quality)")
        }
    }

    func testPaletteQualitiesShrinkRichImagesWithoutVisibleLoss() throws {
        let source = Self.screenshotLikePixels(width: 480, height: 320)
        let image = try XCTUnwrap(source.makeTruecolorImage())
        let lossless = try XCTUnwrap(ScreenshotEncoder.pngData(from: image, quality: .lossless))
        let high = try XCTUnwrap(ScreenshotEncoder.pngData(from: image, quality: .high))
        let compact = try XCTUnwrap(ScreenshotEncoder.pngData(from: image, quality: .compact))

        XCTAssertLessThan(Double(high.count), Double(lossless.count) * 0.6)
        XCTAssertLessThanOrEqual(compact.count, high.count)
        XCTAssertGreaterThan(Self.psnr(source, try Self.decode(high)), 38)
        XCTAssertGreaterThan(Self.psnr(source, try Self.decode(compact)), 32)
    }

    func testPaletteKeepsAnnotationColorsExact() throws {
        // A saturated annotation stroke over a photo-like gradient must keep
        // its exact color rather than being dithered into its surroundings.
        let width = 200, height = 120
        var source = Self.screenshotLikePixels(width: width, height: height).bytes
        let red: [UInt8] = [255, 59, 48]
        for y in 50..<60 {
            for x in 0..<width { source.replaceSubrange((y * width + x) * 3..<(y * width + x) * 3 + 3, with: red) }
        }
        let pixels = RGBPixels(width: width, height: height, bytes: source)
        let data = try XCTUnwrap(ScreenshotEncoder.pngData(from: try XCTUnwrap(pixels.makeTruecolorImage()), quality: .high))
        let decoded = try Self.decode(data)
        let offset = (55 * width + 100) * 3
        XCTAssertEqual(Array(decoded.bytes[offset..<offset + 3]), red)
    }

    func testRetinaCapturesRecordTheirPointSize() throws {
        let source = Self.screenshotLikePixels(width: 200, height: 100)
        let data = try XCTUnwrap(ScreenshotEncoder.pngData(
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
