import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// How much the saved PNG may trade exact pixels for size. Every option is
/// still a PNG, so files keep pasting into terminals, browsers and chat apps.
enum ImageQuality: String, CaseIterable {
    /// Every pixel exactly as captured (truecolor PNG).
    case lossless
    /// 256-color palette with light dithering. Visually identical for UI, text
    /// and annotations; typically 3–5× smaller than lossless.
    case high
    /// 64-color palette. Smaller still; photos and soft gradients may look
    /// grainy when zoomed in.
    case compact

    static let `default`: ImageQuality = .high

    var title: String {
        switch self {
        case .lossless: return "Lossless (largest)"
        case .high: return "High (recommended)"
        case .compact: return "Compact (smallest)"
        }
    }

    /// Palette sizes to try; the smallest resulting file wins. Compact also
    /// tries 256 colors because dithering a small palette over dark gradients
    /// can cost more bytes than it saves.
    var paletteSizes: [Int] {
        switch self {
        case .lossless: return []
        case .high: return [256]
        case .compact: return [64, 256]
        }
    }
}

enum ScreenshotEncoder {
    /// Encodes `image` as a PNG. Lossy qualities fall back to lossless whenever
    /// that is not larger, so we never ship a worse file for no gain, and
    /// otherwise keep the smallest palette candidate.
    /// `pointSize` sets the PNG's DPI so Retina captures open at their on-screen size.
    static func pngData(from image: CGImage, pointSize: CGSize? = nil, quality: ImageQuality) -> Data? {
        guard let pixels = RGBPixels(image: image) else { return nil }
        let properties = dpiProperties(pixelWidth: image.width, pixelHeight: image.height, pointSize: pointSize)
        var best = encode(pixels.makeTruecolorImage(), properties: properties)
        for paletteSize in quality.paletteSizes {
            guard let indexed = PaletteQuantizer.quantize(pixels, maxColors: paletteSize),
                  let candidate = encode(indexed.makeImage(width: pixels.width, height: pixels.height), properties: properties) else { continue }
            if best.map({ candidate.count < $0.count }) ?? true {
                best = candidate
            }
        }
        return best
    }

    private static func encode(_ image: CGImage?, properties: [CFString: Any]) -> Data? {
        guard let image else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
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

struct IndexedPixels {
    /// Packed RGB triples, at most 256 entries.
    let palette: [UInt8]
    let indices: [UInt8]

    var colorCount: Int { palette.count / 3 }

    func makeImage(width: Int, height: Int) -> CGImage? {
        guard indices.count == width * height,
              let space = CGColorSpace(indexedBaseSpace: RGBPixels.colorSpace, last: colorCount - 1, colorTable: palette),
              let provider = CGDataProvider(data: Data(indices) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

/// Median-cut palette refined with k-means, then mapped with gentle
/// Floyd–Steinberg dithering. Colors already in the palette map exactly, so
/// flat UI areas and annotation strokes stay clean and noise-free.
enum PaletteQuantizer {
    /// Fraction of quantization error carried to neighbors. Below 1 to keep
    /// dithering grain out of near-flat areas.
    private static let ditherStrength: Float = 0.75
    /// Caps carried error so dithering doesn't smear across hard edges.
    private static let maxCarriedError: Float = 24
    private static let refinementPasses = 4

    static func quantize(_ pixels: RGBPixels, maxColors: Int) -> IndexedPixels? {
        let maxColors = min(max(maxColors, 2), 256)
        if let exact = exactPalette(pixels, maxColors: maxColors) {
            return exact
        }
        let histogram = Histogram(pixels)
        let palette = refine(medianCut(histogram, maxColors: maxColors), histogram: histogram)
        guard !palette.isEmpty else { return nil }
        return map(pixels, palette: palette)
    }

    /// Images with few enough distinct colors are encoded losslessly.
    private static func exactPalette(_ pixels: RGBPixels, maxColors: Int) -> IndexedPixels? {
        var lookup: [UInt32: UInt8] = [:]
        var palette: [UInt8] = []
        var indices = [UInt8](repeating: 0, count: pixels.width * pixels.height)
        let bytes = pixels.bytes
        for pixel in 0..<indices.count {
            let r = bytes[pixel * 3], g = bytes[pixel * 3 + 1], b = bytes[pixel * 3 + 2]
            let key = UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b)
            if let index = lookup[key] {
                indices[pixel] = index
                continue
            }
            guard lookup.count < maxColors else { return nil }
            let index = UInt8(lookup.count)
            lookup[key] = index
            palette += [r, g, b]
            indices[pixel] = index
        }
        return IndexedPixels(palette: palette, indices: indices)
    }

    /// Distinct colors bucketed at 5 bits per channel, keeping the exact mean
    /// of each bucket so palette entries land on real on-screen colors.
    private struct Histogram {
        struct Entry {
            var color: SIMD3<Float>
            var weight: Float
        }

        let entries: [Entry]

        init(_ pixels: RGBPixels) {
            let binCount = 1 << 15
            var counts = [Int](repeating: 0, count: binCount)
            var sums = [SIMD3<Float>](repeating: .zero, count: binCount)
            let bytes = pixels.bytes
            for pixel in 0..<(pixels.width * pixels.height) {
                let r = bytes[pixel * 3], g = bytes[pixel * 3 + 1], b = bytes[pixel * 3 + 2]
                let bin = Int(r >> 3) << 10 | Int(g >> 3) << 5 | Int(b >> 3)
                counts[bin] += 1
                sums[bin] += SIMD3(Float(r), Float(g), Float(b))
            }
            var entries: [Entry] = []
            for bin in 0..<binCount where counts[bin] > 0 {
                let weight = Float(counts[bin])
                entries.append(Entry(color: sums[bin] / weight, weight: weight))
            }
            self.entries = entries
        }
    }

    private struct Box {
        var range: Range<Int>
        var error: Float
    }

    private static func medianCut(_ histogram: Histogram, maxColors: Int) -> [SIMD3<Float>] {
        var entries = histogram.entries
        guard !entries.isEmpty else { return [] }
        var boxes = [Box(range: entries.indices, error: boxError(entries[entries.indices]))]

        while boxes.count < maxColors {
            // Split whichever box hides the most error.
            guard let target = boxes.indices.filter({ boxes[$0].range.count > 1 && boxes[$0].error > 0 })
                .max(by: { boxes[$0].error < boxes[$1].error }) else { break }
            let range = boxes[target].range
            let axis = widestAxis(entries[range])
            entries[range].sort { lhs, rhs in
                lhs.color[axis] != rhs.color[axis] ? lhs.color[axis] < rhs.color[axis] : lhs.weight < rhs.weight
            }
            let half = entries[range].reduce(0) { $0 + $1.weight } / 2
            var running: Float = 0
            var split = range.lowerBound + 1
            for index in range {
                running += entries[index].weight
                if running >= half {
                    split = min(max(index + 1, range.lowerBound + 1), range.upperBound - 1)
                    break
                }
            }
            let lower = range.lowerBound..<split
            let upper = split..<range.upperBound
            boxes[target] = Box(range: lower, error: boxError(entries[lower]))
            boxes.append(Box(range: upper, error: boxError(entries[upper])))
        }
        return boxes.map { mean(entries[$0.range]) }
    }

    private static func mean(_ entries: ArraySlice<Histogram.Entry>) -> SIMD3<Float> {
        var sum = SIMD3<Float>.zero
        var weight: Float = 0
        for entry in entries {
            sum += entry.color * entry.weight
            weight += entry.weight
        }
        return weight > 0 ? sum / weight : .zero
    }

    private static func boxError(_ entries: ArraySlice<Histogram.Entry>) -> Float {
        let center = mean(entries)
        return entries.reduce(0) { total, entry in
            let delta = entry.color - center
            return total + (delta * delta).sum() * entry.weight
        }
    }

    private static func widestAxis(_ entries: ArraySlice<Histogram.Entry>) -> Int {
        var low = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var high = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for entry in entries {
            low = pointwiseMin(low, entry.color)
            high = pointwiseMax(high, entry.color)
        }
        let spread = high - low
        if spread.x >= spread.y && spread.x >= spread.z { return 0 }
        return spread.y >= spread.z ? 1 : 2
    }

    private static func refine(_ seed: [SIMD3<Float>], histogram: Histogram) -> [SIMD3<Float>] {
        var palette = seed
        for _ in 0..<refinementPasses {
            var sums = [SIMD3<Float>](repeating: .zero, count: palette.count)
            var weights = [Float](repeating: 0, count: palette.count)
            for entry in histogram.entries {
                let index = nearest(entry.color, in: palette)
                sums[index] += entry.color * entry.weight
                weights[index] += entry.weight
            }
            for index in palette.indices where weights[index] > 0 {
                palette[index] = sums[index] / weights[index]
            }
        }
        return palette.map { ($0.rounded(.toNearestOrEven)).clamped(lowerBound: .zero, upperBound: SIMD3(repeating: 255)) }
    }

    private static func nearest(_ color: SIMD3<Float>, in palette: [SIMD3<Float>]) -> Int {
        var best = 0
        var bestDistance = Float.greatestFiniteMagnitude
        for index in palette.indices {
            let delta = palette[index] - color
            let distance = (delta * delta).sum()
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    private static func map(_ pixels: RGBPixels, palette: [SIMD3<Float>]) -> IndexedPixels {
        let width = pixels.width
        let height = pixels.height
        let bytes = pixels.bytes

        var exact: [UInt32: UInt8] = [:]
        for (index, color) in palette.enumerated() {
            let key = UInt32(color.x) << 16 | UInt32(color.y) << 8 | UInt32(color.z)
            if exact[key] == nil { exact[key] = UInt8(index) }
        }
        // Nearest-entry cache at 7 bits per channel; with error diffusion an
        // off-by-one pick is corrected by the next pixels anyway.
        let unknown = UInt16.max
        var cache = [UInt16](repeating: unknown, count: 1 << 21)

        var indices = [UInt8](repeating: 0, count: width * height)
        // Error rows padded by one pixel each side so neighbors need no bounds checks.
        var current = [SIMD3<Float>](repeating: .zero, count: width + 2)
        var next = [SIMD3<Float>](repeating: .zero, count: width + 2)

        for y in 0..<height {
            let leftToRight = y % 2 == 0
            let step = leftToRight ? 1 : -1
            var x = leftToRight ? 0 : width - 1
            for _ in 0..<width {
                let pixel = y * width + x
                let source = SIMD3(Float(bytes[pixel * 3]), Float(bytes[pixel * 3 + 1]), Float(bytes[pixel * 3 + 2]))
                let target = (source + current[x + 1]).rounded(.toNearestOrEven)
                    .clamped(lowerBound: .zero, upperBound: SIMD3(repeating: 255))
                let r = UInt32(target.x), g = UInt32(target.y), b = UInt32(target.z)

                let index: Int
                if let match = exact[r << 16 | g << 8 | b] {
                    index = Int(match)
                } else {
                    let key = Int(r >> 1) << 14 | Int(g >> 1) << 7 | Int(b >> 1)
                    if cache[key] == unknown {
                        cache[key] = UInt16(nearest(target, in: palette))
                    }
                    index = Int(cache[key])
                }
                indices[pixel] = UInt8(index)

                let error = ((target - palette[index]) * ditherStrength)
                    .clamped(lowerBound: SIMD3(repeating: -maxCarriedError), upperBound: SIMD3(repeating: maxCarriedError))
                if error != .zero {
                    let ahead = x + 1 + step
                    let behind = x + 1 - step
                    current[ahead] += error * (7.0 / 16.0)
                    next[behind] += error * (3.0 / 16.0)
                    next[x + 1] += error * (5.0 / 16.0)
                    next[ahead] += error * (1.0 / 16.0)
                }
                x += step
            }
            swap(&current, &next)
            for i in next.indices { next[i] = .zero }
        }

        var flatPalette: [UInt8] = []
        flatPalette.reserveCapacity(palette.count * 3)
        for color in palette {
            flatPalette += [UInt8(color.x), UInt8(color.y), UInt8(color.z)]
        }
        return IndexedPixels(palette: flatPalette, indices: indices)
    }
}
