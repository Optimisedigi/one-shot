import Foundation

/// The "Image quality" preference used for every saved or copied screenshot.
enum ImageQualitySettings {
    static let key = "imageQuality"

    static func quality(in defaults: UserDefaults = .standard) -> ImageQuality {
        defaults.string(forKey: key).flatMap(ImageQuality.init(rawValue:)) ?? .default
    }

    static func setQuality(_ quality: ImageQuality, in defaults: UserDefaults = .standard) {
        defaults.set(quality.rawValue, forKey: key)
    }
}
