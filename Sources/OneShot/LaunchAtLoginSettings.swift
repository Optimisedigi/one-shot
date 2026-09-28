import Foundation
import ServiceManagement

/// Keeps the macOS login item in step with the "Open One Shot at login" setting.
///
/// `SMAppService` registers the exact bundle that is running, so the login item
/// goes stale whenever the app is reinstalled (the bundle and its signature are
/// replaced), moved, or started from a transient location such as the disk
/// image, `~/Downloads` or `.build`. The setting is therefore stored here and
/// the registration is repaired on every launch.
enum LaunchAtLoginSettings {
    private static let desiredKey = "launchAtLoginDesired"

    /// The user's choice, followed both by the checkbox and by the repair pass.
    static var isDesired: Bool {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: desiredKey) == nil {
                // First launch after upgrading: adopt whatever earlier builds
                // registered, so the repair pass cannot switch a setting off.
                defaults.set(SMAppService.mainApp.status != .notRegistered, forKey: desiredKey)
            }
            return defaults.bool(forKey: desiredKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: desiredKey)
        }
    }

    /// Whether macOS currently has the login item registered and enabled.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registered, but macOS is waiting for the user to approve it in
    /// System Settings → General → Login Items.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        let previous = isDesired
        isDesired = enabled
        do {
            try applyRegistration()
        } catch {
            isDesired = previous
            throw error
        }
    }

    /// Repairs the login item so it matches the stored setting. Runs on every
    /// launch because reinstalling or replacing the app invalidates the
    /// registration macOS kept for the old bundle. Touches no UI, so it is safe
    /// to call off the main thread (the status XPC call can stall for seconds).
    static func syncWithSystem() {
        do {
            try applyRegistration()
        } catch {
            NSLog("LaunchAtLogin: could not sync login item: \(error)")
        }
    }

    private static func applyRegistration() throws {
        let service = SMAppService.mainApp
        let before = service.status

        if before == .notFound {
            // Stale item left by an app that was moved or replaced. Clear it
            // first so a fresh registration cannot collide with it.
            NSLog("LaunchAtLogin: clearing stale login item from a moved or replaced app")
            try? service.unregister()
        }

        if isDesired {
            guard canRegisterCurrentBundle else {
                throw LaunchAtLoginError.temporaryLocation(Bundle.main.bundlePath)
            }
            if service.status != .enabled, service.status != .requiresApproval {
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }

        NSLog("LaunchAtLogin: desired=\(isDesired); status \(String(describing: before)) -> \(String(describing: service.status))")
    }

    /// A login item opens the bundle that registered it, so registering from a
    /// Gatekeeper-translocated copy (disk image or Downloads) or from a bare
    /// `swift run` executable would create an item that can never open at login.
    private static var canRegisterCurrentBundle: Bool {
        let path = Bundle.main.bundlePath
        return path.hasSuffix(".app") && !path.contains("AppTranslocation")
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case temporaryLocation(String)

    var errorDescription: String? {
        switch self {
        case .temporaryLocation(let path):
            return "One Shot is running from a temporary location (\(path)). Move One Shot to your Applications folder, open it from there, and turn this setting on again."
        }
    }
}
