import AppKit
import CoreGraphics

enum ScreenPermissionManager {
    static func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        let granted = CGRequestScreenCaptureAccess()
        if !granted {
            showPermissionAlert()
        }
        return granted
    }

    private static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission is required"
        alert.informativeText = "Grant Shotter permission in System Settings → Privacy & Security → Screen & System Audio Recording, then restart the app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
