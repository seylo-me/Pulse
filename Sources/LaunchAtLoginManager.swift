import Foundation
import ServiceManagement
import AppKit

// MARK: - Launch At Login Manager (Default Enabled + Right Click Menu Toggle)
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private let userDefaultsKey = "sysbar_launch_at_login"
    
    var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                let status = SMAppService.mainApp.status
                if status == .enabled {
                    return true
                }
            }
            // Check System Events fallback
            return checkSystemEventsLoginItem()
        }
        set {
            setLaunchAtLogin(newValue)
        }
    }
    
    /// Called on app startup to guarantee launch-at-login by default on first launch
    func setupDefaultLaunchAtLogin() {
        let initializedKey = "sysbar_launch_at_login_initialized_v1"
        let alreadyInitialized = UserDefaults.standard.bool(forKey: initializedKey)
        
        if !alreadyInitialized {
            UserDefaults.standard.set(true, forKey: initializedKey)
            setLaunchAtLogin(true)
        } else {
            // Respect user preference if previously saved
            if UserDefaults.standard.bool(forKey: userDefaultsKey) {
                setLaunchAtLogin(true)
            }
        }
    }
    
    func setLaunchAtLogin(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey)
        
        // 1. Modern ServiceManagement API (macOS 13+)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("Pulse: SMAppService registration notice: \(error.localizedDescription)")
            }
        }
        
        // 2. Universal macOS System Events Login Item (Guarantees reliability across macOS)
        let bundlePath = Bundle.main.bundlePath
        if enabled {
            let script = """
            tell application "System Events"
                set pulseItems to (every login item whose name is "Pulse")
                repeat with anItem in pulseItems
                    delete anItem
                end repeat
                make new login item at end with properties {path:"\(bundlePath)", hidden:false, name:"Pulse"}
            end tell
            """
            executeAppleScript(script)
        } else {
            let script = """
            tell application "System Events"
                set pulseItems to (every login item whose name is "Pulse")
                repeat with anItem in pulseItems
                    delete anItem
                end repeat
            end tell
            """
            executeAppleScript(script)
        }
    }
    
    func toggle() {
        setLaunchAtLogin(!isEnabled)
    }
    
    private func checkSystemEventsLoginItem() -> Bool {
        let script = "tell application \"System Events\" to return exists login item \"Pulse\""
        if let res = executeAppleScript(script), res.trimmingCharacters(in: .whitespacesAndNewlines) == "true" {
            return true
        }
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
    
    @discardableResult
    private func executeAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if let err = error {
            NSLog("Pulse AppleScript Notice: \(err)")
            return nil
        }
        return output.stringValue
    }
}
