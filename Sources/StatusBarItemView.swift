import AppKit

// MARK: - 1. System Status Bar View (Net Speed + SSD + CPU + MEM)
class SystemStatusBarView: NSView {
    
    private var snapshot: SystemSnapshot = .initial
    var onSectionClicked: ((SystemTab) -> Void)?
    var onRightClicked: (() -> Void)?
    
    let netWidth: CGFloat = 46.0
    let ssdWidth: CGFloat = 36.0
    let cpuWidth: CGFloat = 34.0
    let memWidth: CGFloat = 36.0
    
    var totalWidth: CGFloat {
        return netWidth + ssdWidth + cpuWidth + memWidth
    }
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(snapshot: SystemSnapshot) {
        self.snapshot = snapshot
        self.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let isDarkMode = (self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua) || (self.effectiveAppearance.name == .darkAqua || self.effectiveAppearance.name == .vibrantDark)
        let primaryColor: NSColor = isDarkMode ? .white : NSColor(white: 0.1, alpha: 1.0)
        let secondaryColor: NSColor = isDarkMode ? NSColor(white: 0.72, alpha: 1.0) : NSColor(white: 0.35, alpha: 1.0)
        let iconColor: NSColor = isDarkMode ? .white : .black
        
        // Exact SF Pro Medium from Figma design
        let fontSmall = NSFont.systemFont(ofSize: 8.5, weight: .medium)
        let fontRegular = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        
        let row1Y: CGFloat = 11.5
        let row2Y: CGFloat = 1.5
        
        // ── 1. 网速栏 (紧凑无死腔，SVG Chevron Arrow on the RIGHT of data)
        let upStr = formatSpeed(snapshot.uploadSpeed)
        let downStr = formatSpeed(snapshot.downloadSpeed)
        
        let rightX: CGFloat = 35.0
        let arrowX: CGFloat = 37.0
        
        drawTextRightAligned(upStr, rightX: rightX, y: row1Y, font: fontRegular, color: primaryColor)
        drawTextRightAligned(downStr, rightX: rightX, y: row2Y, font: fontRegular, color: primaryColor)
        
        // Exact optical capHeight center alignment: mid = rowY + 4.8pt
        drawUpChevron(x: arrowX, midY: row1Y + 4.8, color: iconColor)
        drawDownChevron(x: arrowX, midY: row2Y + 4.8, color: iconColor)
        
        // ── 2. SSD 栏 (x: 46 ... 82)
        let ssdCenterX: CGFloat = 46.0 + (ssdWidth / 2.0)
        drawTextCentered("SSD", centerX: ssdCenterX, y: row1Y, font: fontSmall, color: secondaryColor)
        let ssdVal = String(format: "%.0f%%", snapshot.diskUsage)
        let ssdColor = snapshot.diskUsage > 85 ? NSColor.systemRed : primaryColor
        drawTextCentered(ssdVal, centerX: ssdCenterX, y: row2Y, font: fontRegular, color: ssdColor)
        
        // ── 3. CPU 栏 (x: 82 ... 116)
        let cpuCenterX: CGFloat = 82.0 + (cpuWidth / 2.0)
        drawTextCentered("CPU", centerX: cpuCenterX, y: row1Y, font: fontSmall, color: secondaryColor)
        let cpuVal = String(format: "%.0f%%", snapshot.cpuUsage)
        let cpuColor = snapshot.cpuUsage > 80 ? NSColor.systemRed : (snapshot.cpuUsage > 50 ? NSColor.systemOrange : primaryColor)
        drawTextCentered(cpuVal, centerX: cpuCenterX, y: row2Y, font: fontRegular, color: cpuColor)
        
        // ── 4. MEM 栏 (x: 116 ... 152)
        let memCenterX: CGFloat = 116.0 + (memWidth / 2.0)
        drawTextCentered("MEM", centerX: memCenterX, y: row1Y, font: fontSmall, color: secondaryColor)
        let memVal = String(format: "%.0f%%", snapshot.memUsage)
        let memColor = snapshot.memUsage > 85 ? NSColor.systemRed : primaryColor
        drawTextCentered(memVal, centerX: memCenterX, y: row2Y, font: fontRegular, color: memColor)
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            onRightClicked?()
            return
        }
        let loc = convert(event.locationInWindow, from: nil)
        if loc.x < netWidth {
            onSectionClicked?(.traffic)
        } else {
            onSectionClicked?(.hardware)
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        onRightClicked?()
    }
    
    private func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
    
    private func drawTextCentered(_ text: String, centerX: CGFloat, y: CGFloat, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: centerX - size.width / 2.0, y: y)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
    
    private func drawTextRightAligned(_ text: String, rightX: CGFloat, y: CGFloat, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: rightX - size.width, y: y)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
    
    private func formatSpeed(_ kb: Double) -> String {
        if kb >= 1024.0 * 1024.0 {
            return String(format: "%.1f G", kb / (1024.0 * 1024.0))
        } else if kb >= 1024.0 {
            return String(format: "%.1f M", kb / 1024.0)
        } else {
            return String(format: "%.0f K", kb)
        }
    }
    
    // MARK: - Exact Optical-Centered SVG Chevron Arrows from Figma Design
    private func drawUpChevron(x: CGFloat, midY: CGFloat, color: NSColor) {
        let w: CGFloat = 4.2
        let h: CGFloat = 3.6
        let inset: CGFloat = 0.8
        let b = midY - h / 2.0
        let t = midY + h / 2.0
        
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: b))
        path.line(to: NSPoint(x: x + w / 2.0, y: t))
        path.line(to: NSPoint(x: x + w, y: b))
        path.line(to: NSPoint(x: x + w / 2.0, y: b + inset))
        path.close()
        color.setFill()
        path.fill()
    }
    
    private func drawDownChevron(x: CGFloat, midY: CGFloat, color: NSColor) {
        let w: CGFloat = 4.2
        let h: CGFloat = 3.6
        let inset: CGFloat = 0.8
        let b = midY - h / 2.0
        let t = midY + h / 2.0
        
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: t))
        path.line(to: NSPoint(x: x + w / 2.0, y: b))
        path.line(to: NSPoint(x: x + w, y: t))
        path.line(to: NSPoint(x: x + w / 2.0, y: t - inset))
        path.close()
        color.setFill()
        path.fill()
    }
}

// MARK: - 2. AI Status Bar View (Displays ONLY ONE active AI Capsule Pill)
class AIStatusBarView: NSView {
    
    private var activeSource: ActiveAISource = .antigravity
    private var currentText: String = "Antigravity · 7d: 99% · 5h: 95%"
    private var isExhausted: Bool = false
    
    var onClick: (() -> Void)?
    var onRightClicked: (() -> Void)?
    
    // Real software icons (loaded from bundle or fallback workspace path)
    static func loadResourceImage(named name: String) -> NSImage? {
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        if let resURL = Bundle.main.resourceURL?.appendingPathComponent("\(name).png"),
           let img = NSImage(contentsOf: resURL) {
            return img
        }
        let bundleResources = Bundle.main.bundlePath + "/Contents/Resources/\(name).png"
        if let img = NSImage(contentsOfFile: bundleResources) {
            return img
        }
        // Development fallback: relative to current working directory
        let cwdFallback = FileManager.default.currentDirectoryPath + "/Resources/\(name).png"
        if let img = NSImage(contentsOfFile: cwdFallback) {
            return img
        }
        return nil
    }
    
    private lazy var agyIcon: NSImage? = {
        AIStatusBarView.loadResourceImage(named: "Antigravity")
    }()
    
    private lazy var cdxIcon: NSImage? = {
        AIStatusBarView.loadResourceImage(named: "Codex")
    }()
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(activeSource: ActiveAISource, text: String, isExhausted: Bool) {
        self.activeSource = activeSource
        self.currentText = text
        self.isExhausted = isExhausted
        self.needsDisplay = true
    }
    
    var currentCapsuleWidth: CGFloat {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        let textWidth = (currentText as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth + 24.0)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let isDarkMode = (self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua) || (self.effectiveAppearance.name == .darkAqua || self.effectiveAppearance.name == .vibrantDark)
        let primaryColor: NSColor = isDarkMode ? .white : NSColor(white: 0.1, alpha: 1.0)
        let fontCapsule = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        
        let totalW = currentCapsuleWidth
        let capsuleRect = NSRect(x: 0.5, y: 2.5, width: totalW - 1.0, height: 17.5)
        let capsulePath = NSBezierPath(roundedRect: capsuleRect, xRadius: 8.75, yRadius: 8.75)
        
        // Background color
        let bgColor: NSColor
        let strokeColor: NSColor
        
        if isExhausted {
            bgColor = isDarkMode ? NSColor(srgbRed: 0.9, green: 0.2, blue: 0.2, alpha: 0.22) : NSColor(srgbRed: 0.9, green: 0.2, blue: 0.2, alpha: 0.12)
            strokeColor = isDarkMode ? NSColor(srgbRed: 1.0, green: 0.35, blue: 0.35, alpha: 0.38) : NSColor(srgbRed: 0.9, green: 0.2, blue: 0.2, alpha: 0.25)
        } else {
            bgColor = isDarkMode ? NSColor(white: 1.0, alpha: 0.15) : NSColor(white: 0.0, alpha: 0.08)
            strokeColor = isDarkMode ? NSColor(white: 1.0, alpha: 0.22) : NSColor(white: 0.0, alpha: 0.12)
        }
        
        bgColor.setFill()
        capsulePath.fill()
        
        strokeColor.setStroke()
        capsulePath.lineWidth = 0.5
        capsulePath.stroke()
        
        // Draw icon by source
        let iconRect = NSRect(x: 5.0, y: 4.5, width: 13.0, height: 13.0)
        switch activeSource {
        case .antigravity:
            if let icon = agyIcon {
                icon.draw(in: iconRect)
            } else {
                drawText("✦", at: NSPoint(x: 5.0, y: 3.5), font: NSFont.systemFont(ofSize: 10, weight: .bold), color: NSColor(hex: 0xA44BFD))
            }
        case .codex:
            if let icon = cdxIcon {
                icon.draw(in: iconRect)
            } else {
                drawText("⚡", at: NSPoint(x: 5.0, y: 3.5), font: NSFont.systemFont(ofSize: 10, weight: .bold), color: NSColor(hex: 0x38BDF8))
            }
        case .claude:
            drawText("✳", at: NSPoint(x: 5.0, y: 3.5), font: NSFont.systemFont(ofSize: 10.5, weight: .bold), color: NSColor(hex: 0xD97706))
        case .grok:
            drawText("𝕏", at: NSPoint(x: 5.5, y: 3.5), font: NSFont.systemFont(ofSize: 9.5, weight: .heavy), color: NSColor(hex: 0xF43F5E))
        case .deepseek:
            drawText("◎", at: NSPoint(x: 5.0, y: 3.5), font: NSFont.systemFont(ofSize: 10, weight: .bold), color: NSColor(hex: 0x0EA5E9))
        }
        
        // Draw text
        let textColor = isExhausted ? NSColor(srgbRed: 1.0, green: 0.4, blue: 0.4, alpha: 1.0) : primaryColor
        let textPoint = NSPoint(x: 21.0, y: 4.0)
        drawText(currentText, at: textPoint, font: fontCapsule, color: textColor)
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            onRightClicked?()
            return
        }
        onClick?()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        onRightClicked?()
    }
    
    private func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
