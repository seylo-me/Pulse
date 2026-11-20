import AppKit
import Foundation

// MARK: - GitHub Release Models
struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String?
    let assets: [GitHubAsset]?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

// MARK: - Pulse Native Auto-Updater
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    static var currentVersion: String {
        return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.5.4"
    }
    
    @Published var hasUpdate: Bool = false
    @Published var latestVersion: String = ""
    @Published var releaseTitle: String = ""
    @Published var releaseNotes: String = ""
    @Published var downloadUrl: String = ""
    @Published var releaseHtmlUrl: String = "https://github.com/suleeeee/Pulse/releases"
    @Published var isChecking: Bool = false
    @Published var isUpdating: Bool = false
    @Published var updateStatus: String = ""
    
    private var checkTimer: Timer?
    private let repoUrl = "https://api.github.com/repos/suleeeee/Pulse/releases/latest"
    
    private init() {
        // Start background check 3 seconds after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.checkForUpdates(manual: false)
            self?.schedulePeriodicChecks()
        }
    }
    
    func schedulePeriodicChecks() {
        checkTimer?.invalidate()
        // Check every 4 hours
        checkTimer = Timer.scheduledTimer(withTimeInterval: 14400, repeats: true) { [weak self] _ in
            self?.checkForUpdates(manual: false)
        }
    }
    
    // MARK: - Version Comparison
    static func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let clean1 = v1.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
        let clean2 = v2.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
        let parts1 = clean1.split(separator: ".").compactMap { Int($0) }
        let parts2 = clean2.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(parts1.count, parts2.count)
        for i in 0..<maxLen {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
    
    // MARK: - Check for Updates
    func checkForUpdates(manual: Bool = false) {
        guard !isChecking && !isUpdating else { return }
        isChecking = true
        
        guard let url = URL(string: repoUrl) else {
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 15.0)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Pulse-App-AutoUpdater", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false
                
                if let error = error {
                    NSLog("[Pulse AutoUpdater] Check error: \(error.localizedDescription)")
                    if manual {
                        self.showAlert(title: "检查更新失败", message: "无法连接到 GitHub 检查最新版本：\(error.localizedDescription)\n请检查网络连接或稍后重试。")
                    }
                    return
                }
                
                guard let data = data else {
                    if manual {
                        self.showAlert(title: "检查更新失败", message: "未获取到有效的版本数据。")
                    }
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    let remoteVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
                    let curVersion = UpdateManager.currentVersion
                    
                    self.releaseTitle = release.name ?? "Pulse v\(remoteVersion)"
                    self.releaseNotes = release.body ?? ""
                    self.releaseHtmlUrl = release.htmlUrl ?? "https://github.com/suleeeee/Pulse/releases"
                    
                    // Pick Universal zip asset first, then any zip
                    var pickedAssetUrl: String? = nil
                    if let assets = release.assets {
                        if let universalZip = assets.first(where: { $0.name.lowercased().contains("universal") && $0.name.hasSuffix(".zip") }) {
                            pickedAssetUrl = universalZip.browserDownloadUrl
                        } else if let anyZip = assets.first(where: { $0.name.hasSuffix(".zip") }) {
                            pickedAssetUrl = anyZip.browserDownloadUrl
                        } else if let universalDmg = assets.first(where: { $0.name.lowercased().contains("universal") && $0.name.hasSuffix(".dmg") }) {
                            pickedAssetUrl = universalDmg.browserDownloadUrl
                        }
                    }
                    self.downloadUrl = pickedAssetUrl ?? ""
                    
                    if UpdateManager.isVersion(remoteVersion, greaterThan: curVersion) {
                        self.hasUpdate = true
                        self.latestVersion = remoteVersion
                        NSLog("[Pulse AutoUpdater] New update found: v\(remoteVersion) (current: v\(curVersion))")
                        
                        if manual {
                            self.promptAndUpdate()
                        }
                    } else {
                        self.hasUpdate = false
                        NSLog("[Pulse AutoUpdater] Already up to date: v\(curVersion)")
                        if manual {
                            self.showAlert(title: "当前已是最新版本", message: "Pulse v\(curVersion) 已经是最新版本，无需更新。")
                        }
                    }
                } catch {
                    NSLog("[Pulse AutoUpdater] JSON parse error: \(error)")
                    if manual {
                        self.showAlert(title: "检查更新失败", message: "解析版本信息失败：\(error.localizedDescription)")
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Prompt User & Perform Update
    func promptAndUpdate() {
        let alert = NSAlert()
        alert.messageText = "发现新版本 Pulse v\(latestVersion)"
        alert.informativeText = "当前运行版本为 v\(UpdateManager.currentVersion)，新版本 v\(latestVersion) 现已可用。\n\n点击「立即更新」将自动下载安装包并重启 Pulse。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "立即更新")
        alert.addButton(withTitle: "稍后再说")
        alert.addButton(withTitle: "查看更新说明")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Start download and update
            startUpdate()
        } else if response == .alertThirdButtonReturn {
            if let url = URL(string: releaseHtmlUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Download & Self-Install
    func startUpdate() {
        guard let url = URL(string: downloadUrl), !downloadUrl.isEmpty else {
            // Fallback: open release page
            if let releaseUrl = URL(string: releaseHtmlUrl) {
                NSWorkspace.shared.open(releaseUrl)
            }
            return
        }
        
        isUpdating = true
        updateStatus = "正在下载更新..."
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] tempLocation, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.isUpdating = false
                    self.showAlert(title: "下载更新失败", message: error.localizedDescription)
                    return
                }
                
                guard let tempLocation = tempLocation else {
                    self.isUpdating = false
                    self.showAlert(title: "下载更新失败", message: "未能获取下载临时文件")
                    return
                }
                
                self.installUpdate(from: tempLocation)
            }
        }
        downloadTask.resume()
    }
    
    private func installUpdate(from tempDownloadedFile: URL) {
        updateStatus = "正在解压并替换应用..."
        
        let fileManager = FileManager.default
        let updateDir = "/tmp/PulseUpdate_\(UUID().uuidString.prefix(6))"
        let zipPath = "\(updateDir)/update.zip"
        let extractedDir = "\(updateDir)/extracted"
        
        do {
            try fileManager.createDirectory(atPath: updateDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(atPath: extractedDir, withIntermediateDirectories: true)
            
            // Move downloaded file to zipPath
            if fileManager.fileExists(atPath: zipPath) {
                try fileManager.removeItem(atPath: zipPath)
            }
            try fileManager.moveItem(at: tempDownloadedFile, to: URL(fileURLWithPath: zipPath))
            
            // Extract zip using ditto
            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-xk", zipPath, extractedDir]
            try ditto.run()
            ditto.waitUntilExit()
            
            // Locate Pulse.app
            var newAppPath: String? = nil
            if fileManager.fileExists(atPath: "\(extractedDir)/Pulse.app") {
                newAppPath = "\(extractedDir)/Pulse.app"
            } else {
                let contents = try fileManager.contentsOfDirectory(atPath: extractedDir)
                if let appFolder = contents.first(where: { $0.hasSuffix(".app") }) {
                    newAppPath = "\(extractedDir)/\(appFolder)"
                }
            }
            
            guard let resolvedNewAppPath = newAppPath else {
                isUpdating = false
                showAlert(title: "更新失败", message: "解压后的安装包中未找到有效的应用 Bundle。")
                return
            }
            
            // Determine target installation path
            var targetAppPath = Bundle.main.bundleURL.path
            if !targetAppPath.hasSuffix(".app") || targetAppPath.contains(".build") {
                targetAppPath = "/Applications/Pulse.app"
            }
            
            // Create detached restart script
            let scriptPath = "/tmp/pulse_updater_runner.sh"
            let scriptContent = """
            #!/bin/bash
            sleep 0.8
            pkill -x Pulse || true
            sleep 0.5
            rm -rf "\(targetAppPath)"
            cp -R "\(resolvedNewAppPath)" "\(targetAppPath)"
            xattr -cr "\(targetAppPath)" 2>/dev/null || true
            rm -rf "\(updateDir)"
            open "\(targetAppPath)"
            """
            
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            let chmod = Process()
            chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmod.arguments = ["+x", scriptPath]
            try chmod.run()
            chmod.waitUntilExit()
            
            // Launch the helper script detached
            let runner = Process()
            runner.executableURL = URL(fileURLWithPath: "/bin/bash")
            runner.arguments = [scriptPath]
            try runner.run()
            
            NSLog("[Pulse AutoUpdater] Update script launched. Terminating current instance...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            isUpdating = false
            showAlert(title: "更新安装失败", message: "执行更新时出错：\(error.localizedDescription)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
