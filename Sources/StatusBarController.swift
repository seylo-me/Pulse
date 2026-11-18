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
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Prevent AppKit from auto-assigning key responder focus ring to any button
    override func becomeKey() {
        super.becomeKey()
        self.makeFirstResponder(nil)
    }
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
    
    private func setupStatusItems() {
        setupSystemStatusItem()
        setupAIStatusItem()
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
    }
    
    private func setupPanels() {
        // 1. System Panel (Traffic & Hardware only - 100% Fit in One Screen)
        let sysRect = NSRect(x: 0, y: 0, width: 360, height: 535)
        systemPanel = PulsePanel(contentRect: sysRect)
        let sysRoot = SystemPopupView(
            monitor: monitor,
            onOpenAI: { [weak self] in self?.openAIPanelFromSystem() },
            onClose: { [weak self] in self?.closeSystemPanel() },
            onExit: { [weak self] in self?.exitSystem() }
        )
        let sysHosting = NSHostingView(rootView: sysRoot)
        sysHosting.frame = sysRect
        sysHosting.wantsLayer = true
        sysHosting.layer?.cornerRadius = 16
        sysHosting.layer?.masksToBounds = true
        systemPanel.contentView = sysHosting
        
        // 2. AI Panel (Independent Quota Center with Selector)
        let aiRect = NSRect(x: 0, y: 0, width: 360, height: 520)
        aiPanel = PulsePanel(contentRect: aiRect)
        let aiRoot = AIPopupView(
            quotaMgr: quotaMgr,
            onOpenSystem: { [weak self] in self?.openSystemPanelFromAI() },
            onClose: { [weak self] in self?.closeAIPanel() },
            onExit: { [weak self] in self?.exitAI() }
        )
        let aiHosting = NSHostingView(rootView: aiRoot)
        aiHosting.frame = aiRect
        aiHosting.autoresizingMask = [.width, .height]
        aiHosting.wantsLayer = true
        aiHosting.layer?.cornerRadius = 16
        aiHosting.layer?.masksToBounds = true
        aiPanel.contentView = aiHosting
    }
    
    // MARK: - Independent Component Exits & Restorations (Mutual Independence - 互不影响)
    func exitAI() {
        closeAIPanel()
        if let item = aiStatusItem {
            NSStatusBar.system.removeStatusItem(item)
            aiStatusItem = nil
            aiItemView = nil
        }
        syncStatusItemFlags()
        
        // If system monitor was also exited, terminate the process
        if systemStatusItem == nil {
            NSApplication.shared.terminate(nil)
        }
    }
    
    func exitSystem() {
        closeSystemPanel()
        if let item = systemStatusItem {
            NSStatusBar.system.removeStatusItem(item)
            systemStatusItem = nil
            systemItemView = nil
        }
        syncStatusItemFlags()
        
        // If AI monitor was also exited, terminate the process
        if aiStatusItem == nil {
            NSApplication.shared.terminate(nil)
        }
    }
    
    func restoreAI() {
        guard aiStatusItem == nil else { return }
        setupAIStatusItem()
        updateAISize()
        syncStatusItemFlags()
    }
    
    func restoreSystem() {
        guard systemStatusItem == nil else { return }
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
                positionPanel(aiPanel, near: button, panelWidth: 360, panelHeight: 520)
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
        
        // 1. Toggle System Status Bar
        let sysItem = NSMenuItem(
            title: "系统监控状态栏",
            action: #selector(toggleSystemStatusItem),
            keyEquivalent: ""
        )
        sysItem.target = self
        sysItem.state = (systemStatusItem != nil) ? .on : .off
        menu.addItem(sysItem)
        
        // 2. Toggle AI Status Bar
        let aiItem = NSMenuItem(
            title: "AI 额度状态栏",
            action: #selector(toggleAIStatusItem),
            keyEquivalent: ""
        )
        aiItem.target = self
        aiItem.state = (aiStatusItem != nil) ? .on : .off
        menu.addItem(aiItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Open System Panel
        let openSys = NSMenuItem(
            title: "打开系统监控面板",
            action: #selector(menuOpenSystemPanel),
            keyEquivalent: ""
        )
        openSys.target = self
        menu.addItem(openSys)
        
        // 4. Open AI Panel
        let openAI = NSMenuItem(
            title: "打开 AI 额度中心",
            action: #selector(menuOpenAIPanel),
            keyEquivalent: ""
        )
        openAI.target = self
        menu.addItem(openAI)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Launch At Login (开机自启)
        let loginItem = NSMenuItem(
            title: "开机自动启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Quit App
        let quit = NSMenuItem(
            title: "退出 Pulse",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
    }
    
    @objc func toggleLaunchAtLogin() {
        LaunchAtLoginManager.shared.toggle()
    }
    
    @objc func toggleSystemStatusItem() {
        if systemStatusItem != nil {
            exitSystem()
        } else {
            restoreSystem()
        }
    }
    
    @objc func toggleAIStatusItem() {
        if aiStatusItem != nil {
            exitAI()
        } else {
            restoreAI()
        }
    }
    
    @objc func menuOpenSystemPanel() {
        if systemStatusItem == nil {
            restoreSystem()
        }
        handleSystemClick(tab: .traffic)
    }
    
    @objc func menuOpenAIPanel() {
        if aiStatusItem == nil {
            restoreAI()
        }
        handleAIClick()
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
        let sysTabs: [(SystemTab, String)] = [
            (.traffic, "tab_traffic_nothing.png"),
            (.hardware, "tab_hardware_accents.png")
        ]
        for (idx, (tab, filename)) in sysTabs.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.4) { [weak self] in
                guard let self = self else { return }
                self.monitor.systemTab = tab
                self.monitor.isPanelVisible = true
                self.systemPanel.makeKeyAndOrderFront(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
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
        
        // 5. Snapshot AI Tabs (All 5 Multi-AI Providers)
        let aiTabs: [(ActiveAISource, String)] = [
            (.antigravity, "tab_antigravity_7d_5h.png"),
            (.codex, "tab_codex_7d_5h.png"),
            (.claude, "tab_claude_reserved.png"),
            (.grok, "tab_grok_reserved.png"),
            (.deepseek, "tab_deepseek_reserved.png")
        ]
        for (idx, (source, filename)) in aiTabs.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(idx) * 0.4) { [weak self] in
                guard let self = self else { return }
                self.systemPanel.orderOut(nil)
                self.monitor.isPanelVisible = false
                self.quotaMgr.selectedAITab = source
                self.quotaMgr.setStatusAI(source)
                self.quotaMgr.isAIPanelVisible = true
                self.aiPanel.makeKeyAndOrderFront(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                exit(0)
            }
        }
    }
}
