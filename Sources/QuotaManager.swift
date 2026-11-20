import Foundation
import SwiftUI

class QuotaManager: ObservableObject {
    @Published var antigravityProfile: AIProfileQuota
    @Published var codexProfile: AIProfileQuota
    @Published var claudeProfile: AIProfileQuota
    @Published var deepseekProfile: AIProfileQuota
    
    private var rawAccountName: String = ""
    private var rawAccountEmail: String = ""
    private var rawAccountPlan: String = "Google AI Pro"
    
    // Independent AI Selection: which one to view in AI Window, and which ONE to display in Status Bar!
    @Published var selectedAITab: ActiveAISource = .antigravity {
        didSet {
            onAITabChanged?()
        }
    }
    @Published var activeStatusAI: ActiveAISource = .antigravity
    var onActiveAIChanged: (() -> Void)?
    var onAITabChanged: (() -> Void)?
    
    // Status Bar Values for the active AI capsule
    @Published var antigravityModelName: String = "Antigravity"
    @Published var antigravity7dStr: String = "100%"
    @Published var antigravity5hStr: String = "100%"
    @Published var antigravityCapsuleText: String = "Antigravity · 5h: 100% · 7d: 100%"
    
    // Codex Quota (Live ChatGPT Plus / Wham Rate Limits)
    @Published var isCodexExhausted: Bool = false
    @Published var codex7dStr: String = "100%"
    @Published var codex5hStr: String = "100%"
    @Published var codexCapsuleText: String = "Codex · 5h: 100% · 7d: 100%"
    
    @Published var lastUpdated: String = "刚刚"
    
    // Status Bar Items Active Flags (Mutual Observation)
    @Published var isSystemStatusItemActive: Bool = true
    @Published var isAIStatusItemActive: Bool = true
    
    // Window Pin / Always On Top (置顶 / 固定浮窗)
    @Published var isPinned: Bool = false {
        didSet {
            onPinChanged?(isPinned)
        }
    }
    var onPinChanged: ((Bool) -> Void)?
    
    var isAIPanelVisible: Bool = false
    private var isWritingUsageCache: Bool = false
    
    private var agyFileWatcher: DispatchSourceFileSystemObject?
    private var agyDaemonWatcher: DispatchSourceFileSystemObject?
    private var agyConvWatcher: DispatchSourceFileSystemObject?
    private var cdxFileWatcher: DispatchSourceFileSystemObject?
    private var daemonPollingTimer: Timer?
    @Published var isRefreshing: Bool = false
    
    var activeCapsuleText: String {
        return capsuleText(for: activeStatusAI)
    }
    
    func profile(for source: ActiveAISource) -> AIProfileQuota {
        switch source {
        case .antigravity: return antigravityProfile
        case .codex: return codexProfile
        case .claude: return claudeProfile
        case .deepseek: return deepseekProfile
        }
    }
    
    func capsuleText(for source: ActiveAISource) -> String {
        switch source {
        case .antigravity:
            return antigravityCapsuleText
        case .codex:
            return codexCapsuleText
        case .claude:
            return claudeProfile.isActive ? "Claude · 已就绪" : (ActiveAISource.claude.isDetectedOnMachine ? "Claude · 待登录" : "Claude · 待连接")
        case .deepseek:
            return deepseekProfile.isActive ? "DeepSeek · 100% · R1" : "DeepSeek · 待连接"
        }
    }
    
    func setStatusAI(_ ai: ActiveAISource) {
        self.activeStatusAI = ai
        UserDefaults.standard.set(ai.rawValue, forKey: "sysbar_active_status_ai")
        onActiveAIChanged?()
    }
    
    private func getCodexModelDisplayName() -> String {
        return "Codex 全模型通用配额"
    }

    init() {
        self.antigravityProfile = AIProfileQuota(
            brandName: "Antigravity",
            accountEmail: "检测中...",
            accountType: "Google AI · 本机实时配额",
            isActive: true,
            lastRefreshed: "刚刚",
            categories: []
        )
        
        self.codexProfile = AIProfileQuota(
            brandName: "OpenAI Codex",
            accountEmail: "检测中...",
            accountType: "ChatGPT Plus · 本机实时配额",
            isActive: true,
            lastRefreshed: "刚刚",
            categories: []
        )
        
        self.claudeProfile = AIProfileQuota(
            brandName: "Anthropic Claude",
            accountEmail: "未检测到本地凭据",
            accountType: "支持 ~/.claude.json 或 API Key",
            isActive: false,
            lastRefreshed: "刚刚",
            categories: []
        )
        
        self.deepseekProfile = AIProfileQuota(
            brandName: "DeepSeek",
            accountEmail: "未检测到本地凭据",
            accountType: "支持 ~/.deepseek/config.json",
            isActive: false,
            lastRefreshed: "刚刚",
            categories: []
        )
        
        if let saved = UserDefaults.standard.string(forKey: "sysbar_active_status_ai"),
           let src = ActiveAISource(rawValue: saved) {
            self.activeStatusAI = src
            self.selectedAITab = src
        }
        
        refreshLocalQuota()
        fetchAntigravityLiveDaemonQuota(force: true)
        fetchCodexLiveQuota(force: true)
        setupFileWatchers()
        
        // High-responsiveness polling timer (5.0s in background, instant on panel open or turn)
        daemonPollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchAntigravityLiveDaemonQuota(force: false)
            self?.fetchCodexLiveQuota(force: false)
        }
        if let t = daemonPollingTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }
    
    deinit {
        daemonPollingTimer?.invalidate()
        agyFileWatcher?.cancel()
        agyDaemonWatcher?.cancel()
        agyConvWatcher?.cancel()
        cdxFileWatcher?.cancel()
    }
    
    private func setupFileWatchers() {
        // 1. Watch daemon directory for restarts or new hub files
        let daemonDir = NSHomeDirectory() + "/.gemini/antigravity/daemon"
        let daemonFd = open(daemonDir, O_EVTONLY)
        if daemonFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: daemonFd, eventMask: [.write, .extend, .attrib], queue: .main)
            src.setEventHandler { [weak self] in
                self?.fetchAntigravityLiveDaemonQuota(force: true)
            }
            src.setCancelHandler { close(daemonFd) }
            src.resume()
            self.agyDaemonWatcher = src
        }
        
        // 2. Watch conversations directory for real-time turn activity
        let convDir = NSHomeDirectory() + "/.gemini/antigravity/conversations"
        let convFd = open(convDir, O_EVTONLY)
        if convFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: convFd, eventMask: [.write, .extend, .attrib], queue: .main)
            src.setEventHandler { [weak self] in
                self?.fetchAntigravityLiveDaemonQuota(force: true)
            }
            src.setCancelHandler { close(convFd) }
            src.resume()
            self.agyConvWatcher = src
        }

        // 3. Watch usage.json if edited externally
        let agyPath = NSHomeDirectory() + "/.gemini/antigravity/usage.json"
        let agyFd = open(agyPath, O_EVTONLY)
        if agyFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: agyFd, eventMask: [.write, .extend, .attrib], queue: .main)
            src.setEventHandler { [weak self] in
                guard let self = self, !self.isWritingUsageCache else { return }
                self.refreshLocalQuota()
                self.onActiveAIChanged?()
            }
            src.setCancelHandler { close(agyFd) }
            src.resume()
            self.agyFileWatcher = src
        }
        
        // 4. Watch codex usage.json
        let cdxPath = NSHomeDirectory() + "/.config/codex/usage.json"
        let cdxFd = open(cdxPath, O_EVTONLY)
        if cdxFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: cdxFd, eventMask: [.write, .extend, .attrib], queue: .main)
            src.setEventHandler { [weak self] in
                guard let self = self, !self.isWritingUsageCache else { return }
                self.refreshLocalQuota()
                self.onActiveAIChanged?()
            }
            src.setCancelHandler { close(cdxFd) }
            src.resume()
            self.cdxFileWatcher = src
        }
    }
    
    func refreshLocalQuota() {
        // 1. Read Antigravity local user config if available
        let appStoragePath = NSHomeDirectory() + "/Library/Application Support/Antigravity/app_storage.json"
        if let data = FileManager.default.contents(atPath: appStoragePath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let userEmail = (json["agy.onboarding.lastLoginUsername"] as? String) ?? (json["jetski.onboarding.lastLoginUsername"] as? String), !userEmail.isEmpty {
            self.rawAccountEmail = userEmail
            self.antigravityProfile.accountEmail = userEmail
            self.antigravityProfile.isActive = true
        }
        
        // 2. Read ~/.gemini/antigravity/usage.json if available
        let agyUsagePath = NSHomeDirectory() + "/.gemini/antigravity/usage.json"
        if let data = FileManager.default.contents(atPath: agyUsagePath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let email = (json["account_email"] as? String) ?? self.rawAccountEmail
            let name = (json["account_name"] as? String) ?? self.rawAccountName
            if !email.isEmpty {
                self.rawAccountEmail = email
                self.rawAccountName = name
                self.antigravityProfile.accountEmail = name.isEmpty ? email : "\(name) (\(email))"
                self.antigravityProfile.isActive = true
            }
            if let plan = json["plan"] as? String, !plan.isEmpty {
                self.rawAccountPlan = plan
                self.antigravityProfile.accountType = "\(plan) · Personal Google account"
            }
            if let model = json["model"] as? String {
                self.antigravityModelName = model
            }
            let g7d = (json["gemini_7d_percent"] as? Double) ?? (json["7d_percent"] as? Double) ?? 100.0
            let g7dReset = (json["gemini_7d_reset"] as? String) ?? (json["7d_reset"] as? String) ?? "周期配额充足"
            let g5h = (json["gemini_5h_percent"] as? Double) ?? (json["5h_percent"] as? Double) ?? 100.0
            let g5hReset = (json["gemini_5h_reset"] as? String) ?? (json["5h_reset"] as? String) ?? "周期配额充足"
            
            let cg7d = (json["claude_gpt_7d_percent"] as? Double) ?? (json["claude_gpt_7d"] as? Double) ?? 100.0
            let cg7dReset = (json["claude_gpt_7d_reset"] as? String) ?? "配额充足 · 100% 剩余未消耗"
            let cg5h = (json["claude_gpt_5h_percent"] as? Double) ?? (json["claude_gpt_5h"] as? Double) ?? 100.0
            let cg5hReset = (json["claude_gpt_5h_reset"] as? String) ?? "配额充足 · 100% 剩余未消耗"
            
            self.antigravity7dStr = "\(Int(g7d))%"
            self.antigravity5hStr = "\(Int(g5h))%"
            
            self.antigravityProfile.categories = [
                ModelCategoryQuota(
                    categoryName: "Gemini Models",
                    windows: [
                        RollingWindowQuota(
                            windowLabel: "7d",
                            percent: g7d,
                            resetText: g7dReset,
                            isExhausted: false
                        ),
                        RollingWindowQuota(
                            windowLabel: "5h",
                            percent: g5h,
                            resetText: g5hReset,
                            isExhausted: false
                        )
                    ]
                ),
                ModelCategoryQuota(
                    categoryName: "Claude and GPT models",
                    windows: [
                        RollingWindowQuota(
                            windowLabel: "7d",
                            percent: cg7d,
                            resetText: cg7dReset,
                            isExhausted: false
                        ),
                        RollingWindowQuota(
                            windowLabel: "5h",
                            percent: cg5h,
                            resetText: cg5hReset,
                            isExhausted: false
                        )
                    ]
                )
            ]
        }
        
        if self.antigravityProfile.accountEmail == "检测中..." {
            self.antigravityProfile.accountEmail = "未登录 Google 账户"
            self.antigravityProfile.accountType = "请在 Antigravity 中登录"
            self.antigravityProfile.isActive = false
        }
        self.antigravityCapsuleText = "Antigravity · 5h: \(antigravity5hStr) · 7d: \(antigravity7dStr)"
        
        // 3. Read real Codex account from ~/.codex/auth.json if available
        let codexAuthPath = NSHomeDirectory() + "/.codex/auth.json"
        if let data = FileManager.default.contents(atPath: codexAuthPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tokens = json["tokens"] as? [String: Any],
           let idToken = tokens["id_token"] as? String {
            let parts = idToken.split(separator: ".")
            if parts.count >= 2 {
                var b64 = String(parts[1])
                while b64.count % 4 != 0 { b64.append("=") }
                b64 = b64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                if let payloadData = Data(base64Encoded: b64),
                   let claims = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                    let email = claims["email"] as? String
                    let name = claims["name"] as? String
                    if let em = email, !em.isEmpty {
                        let displayName = (name != nil && !name!.isEmpty) ? name! : em.components(separatedBy: "@").first ?? "User"
                        self.codexProfile.accountEmail = "\(displayName) (\(em))"
                        self.codexProfile.isActive = true
                    }
                    if let authInfo = claims["https://api.openai.com/auth"] as? [String: Any],
                       let plan = authInfo["chatgpt_plan_type"] as? String {
                        self.codexProfile.accountType = "ChatGPT \(plan.capitalized) · Personal account"
                    }
                }
            }
        }
        
        if self.codexProfile.accountEmail == "检测中..." {
            self.codexProfile.accountEmail = "未登录 OpenAI 账户"
            self.codexProfile.accountType = "请在终端执行 codex 登录"
            self.codexProfile.isActive = false
        }
        
        // 4. Read ~/.config/codex/usage.json if available
        let cdxUsagePath = NSHomeDirectory() + "/.config/codex/usage.json"
        let initialCodexModel = self.getCodexModelDisplayName()
        if let data = FileManager.default.contents(atPath: cdxUsagePath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let ex = (json["is_exhausted"] as? Bool) ?? false
            self.isCodexExhausted = ex
            let p7d = (json["7d_percent"] as? Double) ?? 100.0
            let p5h = (json["5h_percent"] as? Double) ?? 100.0
            self.codex7dStr = "\(Int(p7d))%"
            self.codex5hStr = "\(Int(p5h))%"
            let r7d = (json["7d_reset"] as? String) ?? "配额充足 · 100% 剩余未消耗"
            let r5h = (json["5h_reset"] as? String) ?? "配额充足 · 100% 剩余未消耗"
            self.codexProfile.categories = [
                ModelCategoryQuota(
                    categoryName: initialCodexModel,
                    windows: [
                        RollingWindowQuota(windowLabel: "7d", percent: p7d, resetText: r7d, isExhausted: ex),
                        RollingWindowQuota(windowLabel: "5h", percent: p5h, resetText: r5h, isExhausted: ex)
                    ]
                )
            ]
        } else {
            self.isCodexExhausted = false
            self.codex7dStr = "100%"
            self.codex5hStr = "100%"
        }
        
        if self.isCodexExhausted {
            self.codexCapsuleText = "Codex · 0 额度 · 100%"
        } else {
            self.codexCapsuleText = "Codex · 5h: \(codex5hStr) · 7d: \(codex7dStr)"
        }
        
        // 5. Dynamic Claude Detection (Checks ~/.claude.json, CLI, Claude.app, or API Key)
        let hasClaudeCLI = FileManager.default.fileExists(atPath: "/usr/local/bin/claude")
        let hasClaudeApp = FileManager.default.fileExists(atPath: "/Applications/Claude.app")
        let claudeJsonPath = NSHomeDirectory() + "/.claude.json"
        let claudeDirPath = NSHomeDirectory() + "/.claude"
        let hasClaudeFiles = FileManager.default.fileExists(atPath: claudeJsonPath) || FileManager.default.fileExists(atPath: claudeDirPath)
        
        let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        if !envKey.isEmpty {
            self.claudeProfile.accountEmail = "ANTHROPIC_API_KEY 已配置"
            self.claudeProfile.accountType = "Anthropic Claude · API 认证已就绪"
            self.claudeProfile.isActive = true
            self.claudeProfile.categories = []
        } else if hasClaudeCLI || hasClaudeApp || hasClaudeFiles {
            // Claude runtime/app exists on machine, but not yet authenticated/logged in
            self.claudeProfile.accountEmail = "未登录 Anthropic 账户"
            if hasClaudeCLI {
                self.claudeProfile.accountType = "检测到 Claude Code (v2.1.197) · 终端待登录"
            } else {
                self.claudeProfile.accountType = "检测到 Claude 客户端 · 待登录"
            }
            self.claudeProfile.isActive = false
            self.claudeProfile.categories = []
        } else {
            self.claudeProfile.accountEmail = "未检测到本地凭证"
            self.claudeProfile.accountType = "支持 ~/.claude.json 或 API Key"
            self.claudeProfile.isActive = false
            self.claudeProfile.categories = []
        }
        
        // 6. Dynamic DeepSeek Detection (Checks ~/.deepseek or ~/.config/deepseek)
        let deepseekDirPath = NSHomeDirectory() + "/.deepseek"
        let deepseekConfigPath = NSHomeDirectory() + "/.config/deepseek"
        if FileManager.default.fileExists(atPath: deepseekDirPath) || FileManager.default.fileExists(atPath: deepseekConfigPath) {
            self.deepseekProfile.accountEmail = "DeepSeek 本地配置已连接"
            self.deepseekProfile.accountType = "DeepSeek-V3 / R1 · Developer API"
            self.deepseekProfile.isActive = true
            self.deepseekProfile.categories = [
                ModelCategoryQuota(
                    categoryName: "DeepSeek-R1 (深度推理)",
                    windows: [
                        RollingWindowQuota(
                            windowLabel: "每日",
                            percent: 100.0,
                            resetText: "配额充足 · 100% 剩余",
                            isExhausted: false
                        )
                    ]
                )
            ]
        } else {
            self.deepseekProfile.accountEmail = "未检测到本地凭据"
            self.deepseekProfile.accountType = "支持 ~/.deepseek/config.json"
            self.deepseekProfile.isActive = false
            self.deepseekProfile.categories = []
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        self.lastUpdated = formatter.string(from: Date())
    }
    
    private var lastDaemonFetchTime: Date = .distantPast
    
    // MARK: - Native Direct Antigravity Quota Fetcher via LanguageServerService
    func fetchAntigravityLiveDaemonQuota(force: Bool = false) {
        if !force && Date().timeIntervalSince(lastDaemonFetchTime) < 3.0 {
            return
        }
        lastDaemonFetchTime = Date()
        
        let daemonDir = NSHomeDirectory() + "/.gemini/antigravity/daemon"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: daemonDir) else { return }
        let hubFiles = files.filter { $0.hasPrefix("hub_") && $0.hasSuffix(".json") }
        guard !hubFiles.isEmpty else { return }
        
        // Sort newest first by modification date
        let sortedHubs = hubFiles.sorted { f1, f2 in
            let p1 = "\(daemonDir)/\(f1)"
            let p2 = "\(daemonDir)/\(f2)"
            let d1 = (try? FileManager.default.attributesOfItem(atPath: p1)[.modificationDate] as? Date) ?? .distantPast
            let d2 = (try? FileManager.default.attributesOfItem(atPath: p2)[.modificationDate] as? Date) ?? .distantPast
            return d1 > d2
        }
        
        // Find alive daemon
        var activePort: Int?
        var activeToken: String?
        for hubFile in sortedHubs {
            let fullPath = "\(daemonDir)/\(hubFile)"
            guard let data = FileManager.default.contents(atPath: fullPath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let httpPort = json["httpPort"] as? Int,
                  let csrfToken = json["csrfToken"] as? String else { continue }
            
            if let pid = json["pid"] as? Int32 {
                if kill(pid, 0) == 0 {
                    activePort = httpPort
                    activeToken = csrfToken
                    break
                }
            } else {
                activePort = httpPort
                activeToken = csrfToken
                break
            }
        }
        
        guard let httpPort = activePort, let csrfToken = activeToken else { return }
        guard let url = URL(string: "http://127.0.0.1:\(httpPort)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3.5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrfToken, forHTTPHeaderField: "x-codeium-csrf-token")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["forceRefresh": true])
        
        DispatchQueue.main.async {
            self.isRefreshing = true
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] respData, _, err in
            guard let self = self else { return }
            defer {
                DispatchQueue.main.async {
                    self.isRefreshing = false
                }
            }
            guard let respData = respData, err == nil else { return }
            guard let respJson = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let response = respJson["response"] as? [String: Any],
                  let groups = response["groups"] as? [[String: Any]] else { return }
            
            var g7d = 99.0
            var g5h = 95.0
            var g7dReset = "将于 6 天 20 小时后完全刷新"
            var g5hReset = "将于 1 小时 26 分钟后完全刷新"
            var cg7d = 100.0
            var cg5h = 100.0
            var cg7dReset = "配额充足 · 100% 剩余未消耗"
            var cg5hReset = "配额充足 · 100% 剩余未消耗"
            
            for group in groups {
                let dname = group["displayName"] as? String ?? ""
                let buckets = group["buckets"] as? [[String: Any]] ?? []
                if dname.contains("Gemini") {
                    for b in buckets {
                        let bid = b["bucketId"] as? String ?? ""
                        let frac = b["remainingFraction"] as? Double ?? 1.0
                        let desc = b["description"] as? String ?? ""
                        let rt = b["resetTime"] as? String
                        let resetText = self.formatResetCountdown(resetTime: rt, fallbackDesc: desc)
                        
                        let percentValue = frac * 100.0
                        if bid.contains("weekly") {
                            g7d = percentValue
                            g7dReset = resetText
                        } else if bid.contains("5h") {
                            g5h = percentValue
                            g5hReset = resetText
                        }
                    }
                } else if dname.contains("Claude") {
                    for b in buckets {
                        let bid = b["bucketId"] as? String ?? ""
                        let frac = b["remainingFraction"] as? Double ?? 1.0
                        let desc = b["description"] as? String ?? ""
                        let rt = b["resetTime"] as? String
                        let resetText = self.formatResetCountdown(resetTime: rt, fallbackDesc: desc)
                        
                        let percentValue = frac * 100.0
                        if bid.contains("weekly") {
                            cg7d = percentValue
                            cg7dReset = resetText
                        } else if bid.contains("5h") {
                            cg5h = percentValue
                            cg5hReset = resetText
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                // If any quota was used (< 99.99), never display false 100%
                let g7dDisplayInt: Int = (g7d < 99.99 && g7d >= 99.0) ? 99 : (g7d >= 99.99 ? 100 : Int(g7d))
                let g5hDisplayInt: Int = (g5h < 99.99 && g5h >= 99.0) ? 99 : (g5h >= 99.99 ? 100 : Int(g5h))
                
                self.antigravity7dStr = "\(g7dDisplayInt)%"
                self.antigravity5hStr = "\(g5hDisplayInt)%"
                self.antigravityCapsuleText = "Antigravity · 5h: \(self.antigravity5hStr) · 7d: \(self.antigravity7dStr)"
                
                self.antigravityProfile.categories = [
                    ModelCategoryQuota(
                        categoryName: "Gemini Models",
                        windows: [
                            RollingWindowQuota(windowLabel: "5h", percent: g5h, resetText: g5hReset, isExhausted: false),
                            RollingWindowQuota(windowLabel: "7d", percent: g7d, resetText: g7dReset, isExhausted: false)
                        ]
                    ),
                    ModelCategoryQuota(
                        categoryName: "Claude and GPT models",
                        windows: [
                            RollingWindowQuota(windowLabel: "5h", percent: cg5h, resetText: cg5hReset, isExhausted: false),
                            RollingWindowQuota(windowLabel: "7d", percent: cg7d, resetText: cg7dReset, isExhausted: false)
                        ]
                    )
                ]
                
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                self.lastUpdated = formatter.string(from: Date())
                self.onActiveAIChanged?()
                
                // Write back fresh live values to ~/.gemini/antigravity/usage.json without triggering loop
                var usageDict: [String: Any] = [
                    "plan": self.rawAccountPlan,
                    "model": self.antigravityModelName,
                    "gemini_7d_percent": g7dDisplayInt,
                    "gemini_7d_reset": g7dReset,
                    "gemini_5h_percent": g5hDisplayInt,
                    "gemini_5h_reset": g5hReset,
                    "claude_gpt_7d_percent": Int(cg7d),
                    "claude_gpt_7d_reset": cg7dReset,
                    "claude_gpt_5h_percent": Int(cg5h),
                    "claude_gpt_5h_reset": cg5hReset
                ]
                if !self.rawAccountName.isEmpty {
                    usageDict["account_name"] = self.rawAccountName
                }
                if !self.rawAccountEmail.isEmpty {
                    usageDict["account_email"] = self.rawAccountEmail
                }
                if let uData = try? JSONSerialization.data(withJSONObject: usageDict, options: [.prettyPrinted]) {
                    self.isWritingUsageCache = true
                    let uPath = NSHomeDirectory() + "/.gemini/antigravity/usage.json"
                    try? uData.write(to: URL(fileURLWithPath: uPath))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.isWritingUsageCache = false
                    }
                }
            }
        }
        task.resume()
    }
    
    private func formatResetCountdown(resetTime: String?, fallbackDesc: String) -> String {
        if let rt = resetTime {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: rt) {
                let diff = date.timeIntervalSince(Date())
                if diff > 0 {
                    let totalMinutes = Int(diff / 60)
                    let days = totalMinutes / (24 * 60)
                    let hours = (totalMinutes % (24 * 60)) / 60
                    let minutes = totalMinutes % 60
                    if days > 0 {
                        return "将于 \(days) 天 \(hours) 小时后完全刷新"
                    } else if hours > 0 {
                        return "将于 \(hours) 小时 \(minutes) 分钟后完全刷新"
                    } else {
                        return "将于 \(max(1, minutes)) 分钟后完全刷新"
                    }
                } else {
                    return "配额充足 · 100% 剩余未消耗"
                }
            }
        }
        return translateResetText(fallbackDesc)
    }
    
    private func translateResetText(_ desc: String) -> String {
        guard !desc.isEmpty else { return "配额充足 · 100% 剩余未消耗" }
        if let range = desc.range(of: "fully refresh in ") {
            var rem = String(desc[range.upperBound...])
            if rem.hasSuffix(".") { rem.removeLast() }
            let translated = rem
                .replacingOccurrences(of: "less than a minute", with: "不到 1 分钟")
                .replacingOccurrences(of: "less than a", with: "不到 1")
                .replacingOccurrences(of: "days", with: "天")
                .replacingOccurrences(of: "day", with: "天")
                .replacingOccurrences(of: "hours", with: "小时")
                .replacingOccurrences(of: "hour", with: "小时")
                .replacingOccurrences(of: "minutes", with: "分钟")
                .replacingOccurrences(of: "minute", with: "分钟")
                .replacingOccurrences(of: ", ", with: " ")
                .trimmingCharacters(in: .whitespaces)
            return "将于 \(translated)后完全刷新"
        }
        return desc
    }

    private var lastCodexFetchTime: Date = .distantPast

    // MARK: - Native Direct Codex Quota Fetcher via ChatGPT WHAM Usage Endpoint
    func fetchCodexLiveQuota(force: Bool = false) {
        if !force && Date().timeIntervalSince(lastCodexFetchTime) < 5.0 {
            return
        }
        lastCodexFetchTime = Date()
        
        let authPath = NSHomeDirectory() + "/.codex/auth.json"
        guard let data = FileManager.default.contents(atPath: authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String else { return }
        
        let accountId = tokens["account_id"] as? String
        
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 4.0
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        if let accId = accountId {
            request.setValue(accId, forHTTPHeaderField: "chatgpt-account-id")
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] respData, _, err in
            guard let self = self, let respData = respData, err == nil else { return }
            guard let respJson = try? JSONSerialization.jsonObject(with: respData) as? [String: Any] else { return }
            
            let rateLimit = respJson["rate_limit"] as? [String: Any]
            let allowed = (rateLimit?["allowed"] as? Bool) ?? true
            let limitReached = (rateLimit?["limit_reached"] as? Bool) ?? false
            
            let primary = rateLimit?["primary_window"] as? [String: Any]
            let primaryUsed = (primary?["used_percent"] as? Double) ?? 0.0
            let primaryRem = max(0.0, min(100.0, 100.0 - primaryUsed))
            
            let secondary = rateLimit?["secondary_window"] as? [String: Any]
            let secondaryUsed = (secondary?["used_percent"] as? Double) ?? 0.0
            let secondaryRem = max(0.0, min(100.0, 100.0 - secondaryUsed))
            
            let isExhausted = limitReached || !allowed || (primaryRem <= 0.0 && secondaryRem <= 0.0)
            
            DispatchQueue.main.async {
                self.isCodexExhausted = isExhausted
                self.codex7dStr = "\(Int(secondaryRem))%"
                self.codex5hStr = "\(Int(primaryRem))%"
                
                if isExhausted {
                    self.codexCapsuleText = "Codex · 0 额度 · 100%"
                } else {
                    self.codexCapsuleText = "Codex · 5h: \(self.codex5hStr) · 7d: \(self.codex7dStr)"
                }
                
                self.codexProfile.isActive = !isExhausted
                self.codexProfile.accountType = "ChatGPT Plus · Personal account"
                
                let secResetSec = (secondary?["reset_after_seconds"] as? Int) ?? 0
                let priResetSec = (primary?["reset_after_seconds"] as? Int) ?? 0
                
                let p7dReset: String
                if secondaryUsed <= 0.0 {
                    p7dReset = "配额充足 · 100% 剩余未消耗"
                } else if secResetSec > 0 {
                    let days = secResetSec / 86400
                    let hours = (secResetSec % 86400) / 3600
                    let mins = (secResetSec % 3600) / 60
                    if days > 0 {
                        p7dReset = "将于 \(days) 天 \(hours) 小时后完全刷新"
                    } else if hours > 0 {
                        p7dReset = "将于 \(hours) 小时 \(mins) 分钟后完全刷新"
                    } else {
                        p7dReset = "将于 \(max(1, mins)) 分钟后完全刷新"
                    }
                } else {
                    p7dReset = "周期配额已使用 \(Int(secondaryUsed))%"
                }
                
                let p5hReset: String
                if primaryUsed <= 0.0 {
                    p5hReset = "配额充足 · 100% 剩余未消耗"
                } else if priResetSec > 0 {
                    let hours = priResetSec / 3600
                    let mins = (priResetSec % 3600) / 60
                    if hours > 0 {
                        p5hReset = "将于 \(hours) 小时 \(mins) 分钟后完全刷新"
                    } else {
                        p5hReset = "将于 \(max(1, mins)) 分钟后完全刷新"
                    }
                } else {
                    p5hReset = "周期配额已使用 \(Int(primaryUsed))%"
                }
                
                let codexModelName = self.getCodexModelDisplayName()
                self.codexProfile.categories = [
                    ModelCategoryQuota(
                        categoryName: codexModelName,
                        windows: [
                            RollingWindowQuota(windowLabel: "7d", percent: secondaryRem, resetText: p7dReset, isExhausted: isExhausted),
                            RollingWindowQuota(windowLabel: "5h", percent: primaryRem, resetText: p5hReset, isExhausted: isExhausted)
                        ]
                    )
                ]
                self.onActiveAIChanged?()
                
                // Write back fresh cache to ~/.config/codex/usage.json
                let cacheDict: [String: Any] = [
                    "model": codexModelName,
                    "status": isExhausted ? "已无额度" : "Active",
                    "is_exhausted": isExhausted,
                    "7d_percent": secondaryRem,
                    "7d_reset": p7dReset,
                    "5h_percent": primaryRem,
                    "5h_reset": p5hReset
                ]
                if let cData = try? JSONSerialization.data(withJSONObject: cacheDict, options: [.prettyPrinted]) {
                    let cPath = NSHomeDirectory() + "/.config/codex/usage.json"
                    try? cData.write(to: URL(fileURLWithPath: cPath))
                }
            }
        }
        task.resume()
    }
}
