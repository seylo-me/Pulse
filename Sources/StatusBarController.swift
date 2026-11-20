import AppKit
import SwiftUI

// MARK: - Custom Floating Frosted Glass Panel
class PulsePanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.appearance = NSAppearance(named: .darkAqua)
        self.sharingType = .readOnly
        self.initialFirstResponder = nil
        self.animationBehavior = .none
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Prevent AppKit from auto-assigning key responder focus ring to any button
    override func becomeKey() {
        super.becomeKey()
        self.makeFirstResponder(nil)
    }
}

// MARK: - Flipped Container to Lock Panel Coordinates to Top-Left
class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Status Bar Controller (Two Independent Items: System & Single AI Capsule)
class StatusBarController: NSObject {
    
    // Status Bar Items (Independently Managed - 互不影响)
    private var systemStatusItem: NSStatusItem?
    private var systemItemView: SystemStatusBarView?
    
    private var aiStatusItem: NSStatusItem?
    private var aiItemView: AIStatusBarView?
    
    // Independent Floating Panels
    private var systemPanel: PulsePanel!
    private var aiPanel: PulsePanel!
    
    private let monitor = SystemMonitor()
    private let quotaMgr = QuotaManager()
    private var updateTimer: Timer?
    private var eventMonitor: Any?
    private var keyMonitor: Any?
    
    override init() {
        super.init()
        setupStatusItems()
        setupPanels()
        startTimer()
        setupKeyboardShortcuts()
        setupCallbacks()
        syncStatusItemFlags()
        checkInitialArguments()
    }
    
    deinit {
        stop()
    }
    
    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let kMonitor = keyMonitor {
            NSEvent.removeMonitor(kMonitor)
            keyMonitor = nil
        }
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func syncStatusItemFlags() {
        let sysActive = (systemStatusItem != nil)
        let aiActive = (aiStatusItem != nil)
        monitor.isSystemStatusItemActive = sysActive
        monitor.isAIStatusItemActive = aiActive
        quotaMgr.isSystemStatusItemActive = sysActive
        quotaMgr.isAIStatusItemActive = aiActive
    }
    
    // UserDefaults Keys for Persistent Status Bar Visibility Across Restarts
    private let userDefaultsKeyShowSystem = "sysbar_show_system_item"
    private let userDefaultsKeyShowAI = "sysbar_show_ai_item"
    
    private func setupStatusItems() {
        let showSys = UserDefaults.standard.object(forKey: userDefaultsKeyShowSystem) as? Bool ?? true
        let showAI = UserDefaults.standard.object(forKey: userDefaultsKeyShowAI) as? Bool ?? true
        
        // Failsafe: If both were previously closed, default to showing both so the app is accessible
        if !showSys && !showAI {
            setupSystemStatusItem()
            setupAIStatusItem()
            UserDefaults.standard.set(true, forKey: userDefaultsKeyShowSystem)
            UserDefaults.standard.set(true, forKey: userDefaultsKeyShowAI)
        } else {
            if showSys {
                setupSystemStatusItem()
            }
            if showAI {
                setupAIStatusItem()
            }
        }
    }
    
    private func setupSystemStatusItem() {
        guard systemStatusItem == nil else { return }
        // 1. System Status Item (Net Speed + SSD + CPU + MEM)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        systemStatusItem = item
        if let button = item.button {
            let sysWidth: CGFloat = 152.0
            let view = SystemStatusBarView(frame: NSRect(x: 0, y: 0, width: sysWidth, height: 22))
            systemItemView = view
            view.onSectionClicked = { [weak self] tab in
                self?.handleSystemClick(tab: tab)
            }
            view.onRightClicked = { [weak self, weak view] in
                guard let self = self, let v = view else { return }
                self.showContextMenu(for: v)
            }
            button.addSubview(view)
            button.frame = NSRect(x: 0, y: 0, width: sysWidth, height: 22)
            item.length = sysWidth
            view.update(snapshot: monitor.snapshot)
        }
        syncStatusItemFlags()
    }
    
    private func setupAIStatusItem() {
        guard aiStatusItem == nil else { return }
        // 2. AI Status Item (Displays ONLY ONE active AI Capsule Pill)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        aiStatusItem = item
        if let button = item.button {
            let view = AIStatusBarView(frame: NSRect(x: 0, y: 0, width: 170, height: 22))
            aiItemView = view
            view.onClick = { [weak self] in
                self?.handleAIClick()
            }
            view.onRightClicked = { [weak self, weak view] in
                guard let self = self, let v = view else { return }
                self.showContextMenu(for: v)
            }
            button.addSubview(view)
            updateAISize()
        }
        syncStatusItemFlags()
    }
    
    private func updateAISize() {
        guard let item = aiStatusItem, let view = aiItemView else { return }
        view.update(
            activeSource: quotaMgr.activeStatusAI,
            text: quotaMgr.activeCapsuleText,
            isExhausted: (quotaMgr.activeStatusAI == .codex ? quotaMgr.isCodexExhausted : false)
        )
        let aiWidth = view.currentCapsuleWidth
        item.length = aiWidth
        view.frame = NSRect(x: 0, y: 0, width: aiWidth, height: 22)
        item.button?.frame = NSRect(x: 0, y: 0, width: aiWidth, height: 22)
    }
    
    private func setupCallbacks() {
        quotaMgr.onActiveAIChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.updateAISize()
            }
        }
        
        monitor.onPinChanged = { [weak self] isPinned in
            DispatchQueue.main.async {
                self?.systemPanel?.level = isPinned ? .statusBar : .floating
            }
        }
        
        quotaMgr.onPinChanged = { [weak self] isPinned in
            DispatchQueue.main.async {
                self?.aiPanel?.level = isPinned ? .statusBar : .floating
            }
        }
        
        quotaMgr.onAITabChanged = { [weak self] in
            self?.updateAIPanelHeight(animated: true)
        }
    }
    
    private func setupPanels() {
        // 1. System Panel (Traffic & Hardware only - 100% Fit in One Screen)
        let sysRect = NSRect(x: 0, y: 0, width: 360, height: 540)
        systemPanel = PulsePanel(contentRect: sysRect)
        let sysRoot = SystemPopupView(
            monitor: monitor,
            onOpenAI: { [weak self] in self?.openAIPanelFromSystem() },
            onClose: { [weak self] in self?.closeSystemPanel() },
            onExit: { [weak self] in self?.exitSystem() }
        )
        let sysHosting = NSHostingView(rootView: sysRoot)
        sysHosting.frame = sysRect
        sysHosting.focusRingType = .none
        sysHosting.wantsLayer = true
        sysHosting.layer?.cornerRadius = 16
        sysHosting.layer?.masksToBounds = true
        systemPanel.contentView = sysHosting
        
        // 2. AI Panel (Independent Quota Center with Selector)
        let aiRect = NSRect(x: 0, y: 0, width: 360, height: 448)
        aiPanel = PulsePanel(contentRect: aiRect)
        let aiRoot = AIPopupView(
            quotaMgr: quotaMgr,
            onOpenSystem: { [weak self] in self?.openSystemPanelFromAI() },
            onClose: { [weak self] in self?.closeAIPanel() },
            onExit: { [weak self] in self?.exitAI() }
        )
        let container = FlippedContainerView(frame: aiRect)
        container.wantsLayer = true
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true
        container.autoresizingMask = [.width, .height]
        
        let aiHosting = NSHostingView(rootView: aiRoot)
        aiHosting.frame = aiRect
        aiHosting.focusRingType = .none
        aiHosting.autoresizingMask = [.width, .height]
        aiHosting.wantsLayer = true
        container.addSubview(aiHosting)
        aiPanel.contentView = container
    }
    
    // MARK: - Independent Component Exits & Restorations (Mutual Independence - 互不影响 & 记住用户选择)
    func exitAI() {
        guard systemStatusItem != nil else { return } // 至少保留一个状态栏项目，防止完全无入口退出
        closeAIPanel()
        if let item = aiStatusItem {
            NSStatusBar.system.removeStatusItem(item)
            aiStatusItem = nil
            aiItemView = nil
        }
        UserDefaults.standard.set(false, forKey: userDefaultsKeyShowAI)
        syncStatusItemFlags()
    }
    
    func exitSystem() {
        guard aiStatusItem != nil else { return } // 至少保留一个状态栏项目，防止完全无入口退出
        closeSystemPanel()
        if let item = systemStatusItem {
            NSStatusBar.system.removeStatusItem(item)
            systemStatusItem = nil
            systemItemView = nil
        }
        UserDefaults.standard.set(false, forKey: userDefaultsKeyShowSystem)
        syncStatusItemFlags()
    }
    
    func restoreAI() {
        guard aiStatusItem == nil else { return }
        UserDefaults.standard.set(true, forKey: userDefaultsKeyShowAI)
        setupAIStatusItem()
        updateAISize()
        syncStatusItemFlags()
    }
    
    func restoreSystem() {
        guard systemStatusItem == nil else { return }
        UserDefaults.standard.set(true, forKey: userDefaultsKeyShowSystem)
        setupSystemStatusItem()
        systemItemView?.update(snapshot: monitor.snapshot)
        syncStatusItemFlags()
    }
    
    func openAIPanelFromSystem() {
        closeSystemPanel()
        if aiStatusItem == nil {
            restoreAI()
        }
        handleAIClick()
    }
    
    func openSystemPanelFromAI() {
        closeAIPanel()
        if systemStatusItem == nil {
            restoreSystem()
        }
        handleSystemClick(tab: .traffic)
    }
    
    func closeSystemPanel() {
        systemPanel?.orderOut(nil)
        monitor.isPanelVisible = false
        updateEventMonitorState()
    }
    
    func closeAIPanel() {
        aiPanel?.orderOut(nil)
        quotaMgr.isAIPanelVisible = false
        updateEventMonitorState()
    }
    
    // Toggle System Panel
    func handleSystemClick(tab: SystemTab) {
        if systemStatusItem == nil {
            restoreSystem()
        }
        guard let item = systemStatusItem else { return }
        
        if systemPanel.isVisible && monitor.systemTab == tab {
            closeSystemPanel()
        } else {
            closeAIPanel() // Close AI panel if open
            monitor.systemTab = tab
            monitor.isPanelVisible = true
            monitor.refreshSnapshot()
            
            if let button = item.button {
                positionPanel(systemPanel, near: button, panelWidth: 360, panelHeight: 580)
            }
            systemPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            updateEventMonitorState()
        }
    }
    
    private func currentAIPanelHeight() -> CGFloat {
        switch quotaMgr.selectedAITab {
        case .antigravity:
            return 448
        case .codex:
            return 336
        case .claude, .deepseek:
            return 300
        }
    }

    func updateAIPanelHeight(animated: Bool = true) {
        guard aiPanel.isVisible else { return }
        let height = currentAIPanelHeight()
        
        // 彻底锁定 X 坐标与顶边 Y 坐标，绝不产生水平漂移与顶部震颤
        let x = aiPanel.frame.origin.x
        let topEdge = aiPanel.frame.maxY
        let y = topEdge - height
        let targetRect = NSRect(x: x, y: y, width: 360, height: height)
        
        if abs(aiPanel.frame.height - height) < 1.0 { return }
        
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.20
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                aiPanel.animator().setFrame(targetRect, display: true)
            }
        } else {
            aiPanel.setFrame(targetRect, display: true)
        }
    }

    // Toggle Independent AI Panel
    func handleAIClick() {
        if aiStatusItem == nil {
            restoreAI()
        }
        guard let item = aiStatusItem else { return }
        
        if aiPanel.isVisible {
            closeAIPanel()
        } else {
            closeSystemPanel() // Close System panel if open
            quotaMgr.isAIPanelVisible = true
            quotaMgr.refreshLocalQuota()
            quotaMgr.fetchAntigravityLiveDaemonQuota(force: true)
            quotaMgr.fetchCodexLiveQuota(force: true)
            
            if let button = item.button {
                positionPanel(aiPanel, near: button, panelWidth: 360, panelHeight: currentAIPanelHeight())
            }
            aiPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            updateEventMonitorState()
        }
    }
    
    private func positionPanel(_ p: PulsePanel, near button: NSStatusBarButton, panelWidth: CGFloat, panelHeight: CGFloat) {
        guard let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.frame
        let screen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens[0]
        
        var x = buttonFrame.midX - (panelWidth / 2.0)
        let screenVisible = screen.visibleFrame
        x = max(screenVisible.minX + 8, min(x, screenVisible.maxX - panelWidth - 8))
        
        // Guarantee that the top of the panel is always safely 6pt below the menu bar
        let maxAvailableHeight = max(200.0, buttonFrame.minY - screenVisible.minY - 16.0)
        let actualHeight = min(panelHeight, maxAvailableHeight)
        let y = buttonFrame.minY - actualHeight - 6.0
        
        p.setFrame(NSRect(x: x, y: y, width: panelWidth, height: actualHeight), display: true)
    }
    
    // MARK: - Right-Click Context Menu (Instant Restoration & Control Center)
    func showContextMenu(for view: NSView) {
        let menu = NSMenu(title: "Pulse")
        menu.appearance = NSAppearance(named: .darkAqua)
        menu.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        
        // 0. Header (Brand title & Version)
        let headerItem = NSMenuItem()
        headerItem.isEnabled = false
        headerItem.attributedTitle = NSAttributedString(
            string: "Pulse  v\(UpdateManager.currentVersion)",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
        )
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        
        // 1. Toggle System Status Bar
        let sysItem = createMenuItem(
            title: "系统监控状态栏",
            icon: "waveform.path.ecg",
            action: #selector(toggleSystemStatusItem),
            state: (systemStatusItem != nil) ? .on : .off
        )
        // 至少保留一个状态栏项目，若仅剩系统监控则不可取消勾选
        if systemStatusItem != nil && aiStatusItem == nil {
            sysItem.isEnabled = false
        }
        menu.addItem(sysItem)
        
        // 2. Toggle AI Status Bar
        let aiItem = createMenuItem(
            title: "AI 额度状态栏",
            icon: "sparkles",
            action: #selector(toggleAIStatusItem),
            state: (aiStatusItem != nil) ? .on : .off
        )
        // 至少保留一个状态栏项目，若仅剩 AI 额度则不可取消勾选
        if aiStatusItem != nil && systemStatusItem == nil {
            aiItem.isEnabled = false
        }
        menu.addItem(aiItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Launch At Login (开机自启)
        let loginItem = createMenuItem(
            title: "开机自动启动",
            icon: "arrow.clockwise",
            action: #selector(toggleLaunchAtLogin),
            state: LaunchAtLoginManager.shared.isEnabled ? .on : .off
        )
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Update Check
        if UpdateManager.shared.hasUpdate {
            let updateItem = createMenuItem(
                title: "🚀 立即更新到 v\(UpdateManager.shared.latestVersion)...",
                icon: "arrow.triangle.2.circlepath.circle.fill",
                action: #selector(performUpdate)
            )
            menu.addItem(updateItem)
        } else {
            let updateItem = createMenuItem(
                title: "检查更新...",
                icon: "arrow.triangle.2.circlepath",
                action: #selector(checkUpdatesManual)
            )
            menu.addItem(updateItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Quit App
        let quit = createMenuItem(
            title: "退出 Pulse",
            icon: "power",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
        
        // Position menu safely below the status bar (y = 0 is the bottom edge in unflipped AppKit coords)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: view)
    }
    
    private func createMenuItem(
        title: String,
        icon: String? = nil,
        action: Selector? = nil,
        keyEquivalent: String = "",
        state: NSControl.StateValue = .off
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.state = state
        
        // Refined 11.5pt font (clean, compact, anti-bloat)
        let attr = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .regular)
            ]
        )
        item.attributedTitle = attr
        
        // Crisp SF Symbol (scaled to 11pt)
        if let icon = icon {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                img.isTemplate = true
                item.image = img
            }
        }
        return item
    }
    
    @objc func toggleLaunchAtLogin() {
        LaunchAtLoginManager.shared.toggle()
    }
    
    @objc func toggleSystemStatusItem() {
        if systemStatusItem != nil {
            guard aiStatusItem != nil else { return } // 保护：不能两个都取消勾选
            exitSystem()
        } else {
            restoreSystem()
        }
    }
    
    @objc func toggleAIStatusItem() {
        if aiStatusItem != nil {
            guard systemStatusItem != nil else { return } // 保护：不能两个都取消勾选
            exitAI()
        } else {
            restoreAI()
        }
    }
    
    @objc func checkUpdatesManual() {
        UpdateManager.shared.checkForUpdates(manual: true)
    }
    
    @objc func performUpdate() {
        UpdateManager.shared.promptAndUpdate()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Dynamic Global Outside-Click Monitor (Active ONLY when a panel is open)
    private func updateEventMonitorState() {
        let shouldMonitor = (systemPanel?.isVisible == true) || (aiPanel?.isVisible == true)
        
        if shouldMonitor {
            if eventMonitor == nil {
                eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    guard let self = self else { return }
                    let mouseLoc = NSEvent.mouseLocation
                    
                    if self.systemPanel.isVisible {
                        let pFrame = self.systemPanel.frame
                        let bFrame = self.systemStatusItem?.button?.window?.frame ?? .zero
                        if !pFrame.contains(mouseLoc) && !bFrame.contains(mouseLoc) {
                            if !self.monitor.isPinned {
                                DispatchQueue.main.async { self.closeSystemPanel() }
                            }
                        }
                    }
                    
                    if self.aiPanel.isVisible {
                        let pFrame = self.aiPanel.frame
                        let bFrame = self.aiStatusItem?.button?.window?.frame ?? .zero
                        if !pFrame.contains(mouseLoc) && !bFrame.contains(mouseLoc) {
                            if !self.quotaMgr.isPinned {
                                DispatchQueue.main.async { self.closeAIPanel() }
                            }
                        }
                    }
                }
            }
        } else {
            // Panels are closed: completely tear down the global monitor to achieve 0% CPU and zero system interference
            if let em = eventMonitor {
                NSEvent.removeMonitor(em)
                eventMonitor = nil
            }
        }
    }
    
    private func setupKeyboardShortcuts() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                if self?.systemPanel?.isVisible == true {
                    self?.closeSystemPanel()
                    return nil
                }
                if self?.aiPanel?.isVisible == true {
                    self?.closeAIPanel()
                    return nil
                }
            }
            return event
        }
    }
    
    private func startTimer() {
        systemItemView?.update(snapshot: monitor.snapshot)
        updateAISize()
        
        // Responsive status bar refresh timer (1.5s)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.systemItemView?.update(snapshot: self.monitor.snapshot)
            self.updateAISize()
            if self.quotaMgr.isAIPanelVisible {
                self.quotaMgr.fetchAntigravityLiveDaemonQuota(force: false)
                self.quotaMgr.fetchCodexLiveQuota(force: false)
            }
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    private func checkInitialArguments() {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--snapshot"), idx + 1 < args.count {
            let dir = args[idx + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.snapshotAll(toDir: dir)
            }
        }
    }
    
    func snapshotAll(toDir: String) {
        try? FileManager.default.createDirectory(atPath: toDir, withIntermediateDirectories: true)
        
        // 1. Snapshot system status bar item
        if let sView = systemItemView, let rep = sView.bitmapImageRepForCachingDisplay(in: sView.bounds) {
            sView.cacheDisplay(in: sView.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: "\(toDir)/sysbar_system_item.png"))
            }
        }
        
        // 2. Snapshot AI status item (Antigravity active)
        quotaMgr.setStatusAI(.antigravity)
        updateAISize()
        if let aView = aiItemView, let rep = aView.bitmapImageRepForCachingDisplay(in: aView.bounds) {
            aView.cacheDisplay(in: aView.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: "\(toDir)/sysbar_item_7d_5h.png"))
                try? data.write(to: URL(fileURLWithPath: "\(toDir)/sysbar_ai_item_antigravity.png"))
            }
        }
        
        // 3. Snapshot AI status item (Codex active)
        quotaMgr.setStatusAI(.codex)
        updateAISize()
        if let aView = aiItemView, let rep = aView.bitmapImageRepForCachingDisplay(in: aView.bounds) {
            aView.cacheDisplay(in: aView.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: "\(toDir)/sysbar_ai_item_codex.png"))
            }
        }
        quotaMgr.setStatusAI(.antigravity) // revert
        updateAISize()
        
        // 4. Snapshot System Tabs (Traffic & Hardware)
        let sysTabs: [(SystemTab, String, Double, Double)] = [
            (.traffic, "tab_traffic_nothing.png", 0.1, 0.6),
            (.hardware, "tab_hardware_accents.png", 0.9, 1.4)
        ]
        for (tab, filename, triggerDelay, captureDelay) in sysTabs {
            DispatchQueue.main.asyncAfter(deadline: .now() + triggerDelay) { [weak self] in
                guard let self = self else { return }
                self.monitor.systemTab = tab
                self.monitor.isPanelVisible = true
                self.systemPanel.makeKeyAndOrderFront(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + (captureDelay - triggerDelay)) { [weak self] in
                    guard let self = self, let view = self.systemPanel.contentView else { return }
                    if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                        view.cacheDisplay(in: view.bounds, to: rep)
                        if let data = rep.representation(using: .png, properties: [:]) {
                            try? data.write(to: URL(fileURLWithPath: "\(toDir)/\(filename)"))
                        }
                    }
                }
            }
        }
        
        // 5. Snapshot AI Tabs (All Multi-AI Providers)
        let aiTabs: [(ActiveAISource, String, Double, Double)] = [
            (.antigravity, "tab_antigravity_7d_5h.png", 1.8, 2.3),
            (.codex, "tab_codex_7d_5h.png", 2.6, 3.1),
            (.claude, "tab_claude_reserved.png", 3.4, 3.9),
            (.deepseek, "tab_deepseek_reserved.png", 4.2, 4.7)
        ]
        for (source, filename, triggerDelay, captureDelay) in aiTabs {
            DispatchQueue.main.asyncAfter(deadline: .now() + triggerDelay) { [weak self] in
                guard let self = self else { return }
                self.systemPanel.orderOut(nil)
                self.monitor.isPanelVisible = false
                self.quotaMgr.selectedAITab = source
                self.quotaMgr.setStatusAI(source)
                self.quotaMgr.isAIPanelVisible = true
                let h = self.currentAIPanelHeight()
                self.aiPanel.setFrame(NSRect(x: 100, y: 200, width: 360, height: h), display: true)
                self.aiPanel.contentView?.frame = NSRect(x: 0, y: 0, width: 360, height: h)
                self.aiPanel.makeKeyAndOrderFront(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + (captureDelay - triggerDelay)) { [weak self] in
                    guard let self = self, let view = self.aiPanel.contentView else { return }
                    if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                        view.cacheDisplay(in: view.bounds, to: rep)
                        if let data = rep.representation(using: .png, properties: [:]) {
                            try? data.write(to: URL(fileURLWithPath: "\(toDir)/\(filename)"))
                        }
                    }
                }
            }
        }
        
        if CommandLine.arguments.contains("--exit-after-snapshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
                exit(0)
            }
        }
    }
}
