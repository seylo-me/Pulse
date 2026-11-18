import AppKit
import IOKit
import IOKit.ps

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Automatically enable Launch At Login by default on launch
        LaunchAtLoginManager.shared.setupDefaultLaunchAtLogin()
        statusBarController = StatusBarController()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController.restoreSystem()
        statusBarController.restoreAI()
        statusBarController.handleAIClick()
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusBarController.stop()
    }
}
