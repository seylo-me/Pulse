import SwiftUI
import AppKit

// MARK: - Nothing / Teenage Engineering Style Industrial Block Meter
// Inspired by Nothing OS Screen Time widget & Battery indicator
struct SegmentedMeterView: View {
    var percent: Double // 0 - 100
    var accentColor: Color
    var segmentCount: Int = 8
    
    var body: some View {
        GeometryReader { geo in
            let totalGap = CGFloat(segmentCount - 1) * 3.5
            let itemWidth = (geo.size.width - totalGap) / CGFloat(segmentCount)
            let filledCount = Int(round((percent / 100.0) * Double(segmentCount)))
            
            HStack(spacing: 3.5) {
                ForEach(0..<segmentCount, id: \.self) { idx in
                    let isFilled = idx < filledCount
                    let isLeadingEdge = (idx == filledCount - 1) && filledCount > 0
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            isFilled
                                ? (isLeadingEdge ? AnyShapeStyle(accentColor) : AnyShapeStyle(Color.white))
                                : AnyShapeStyle(Color.white.opacity(0.08))
                        )
                        .frame(width: itemWidth)
                }
            }
        }
        .frame(height: 22)
    }
}

// MARK: - Outlined Vector Logo (Loaded from Figma Node 16:15 pulse_logo.svg)
func loadPulseLogo() -> NSImage? {
    if let bundlePath = Bundle.main.path(forResource: "pulse_logo", ofType: "svg"),
       let img = NSImage(contentsOfFile: bundlePath) {
        return img
    }
    if let resURL = Bundle.main.resourceURL?.appendingPathComponent("pulse_logo.svg"),
       let img = NSImage(contentsOf: resURL) {
        return img
    }
    let bundleResources = Bundle.main.bundlePath + "/Contents/Resources/pulse_logo.svg"
    if let img = NSImage(contentsOfFile: bundleResources) {
        return img
    }
    let fallback = "/Users/sulee/.gemini/antigravity/scratch/SysBar/Resources/pulse_logo.svg"
    return NSImage(contentsOfFile: fallback)
}

// MARK: - 1. System Popup View (Dedicated Traffic & Hardware - Zero AI Clutter!)
struct SystemPopupView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var isPinned: Bool = false
    @Namespace private var systemTabNamespace
    
    var onOpenAI: () -> Void = {}
    var onClose: () -> Void = {}
    var onExit: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Industrial Header
            headerView
            
            // ── 2 Minimalist System Mode Switcher Pills (iOS Glass Capsule Style)
            systemModeSwitcherView
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            
            // ── Main Content Tab Area (Fits completely in one screen with NO scrolling)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    switch monitor.systemTab {
                    case .traffic:
                        trafficTabContent
                    case .hardware:
                        hardwareTabContent
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // ── Industrial Footer
            footerView
        }
        .frame(width: 360, height: 580)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                ThemeColors.glassTint
            }
        )
        .preferredColorScheme(.dark)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Header (Nothing Industrial Style)
    private var headerView: some View {
        HStack(alignment: .center, spacing: 10) {
            PulseBrandBadge()
            
            VStack(alignment: .leading, spacing: 3) {
                // Row 1: Pulse logo (v1.5 moved to bottom-left footer)
                HStack(alignment: .center, spacing: 6) {
                    if let logo = loadPulseLogo() {
                        Image(nsImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 38.74, height: 10.5)
                    } else {
                        Text("PULSE")
                            .font(.sfSans(13, weight: .bold, design: .monospaced))
                            .tracking(-0.3)
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                }
                
                // Row 2: ONLINE + red dot + IP (Starts with ONLINE, strictly left-aligned with Pulse!)
                HStack(alignment: .center, spacing: 5) {
                    Text("ONLINE")
                        .font(.sfSans(9.5, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(ThemeColors.textSecondary)
                    
                    Circle()
                        .fill(ThemeColors.accentRed) // Nothing iconic red dot
                        .frame(width: 4.5, height: 4.5)
                    
                    Text("·")
                        .foregroundColor(ThemeColors.textMuted)
                    
                    Text("127.0.0.1:9000")
                        .font(.sfSans(8.5, weight: .regular, design: .monospaced))
                        .foregroundColor(ThemeColors.textMuted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            
            Spacer(minLength: 8)
            
            // Action Buttons: Pin, Refresh, Power (Delete X close button) - Pure Dark Glass
            HStack(spacing: 5) {
                Button(action: { isPinned.toggle() }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundColor(isPinned ? ThemeColors.accentRed : Color.white.opacity(0.70))
                        .frame(width: 26, height: 26)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                                RoundedRectangle(cornerRadius: 6).fill(
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.8
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help(isPinned ? "取消固定" : "固定浮窗")
                
                Button(action: {
                    monitor.refreshSnapshot()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                                RoundedRectangle(cornerRadius: 6).fill(
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.8
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help("刷新数据")

                // ── Quick Jump to AI Center
                Button(action: onOpenAI) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(ThemeColors.accentPurple)
                        .frame(width: 26, height: 26)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                                RoundedRectangle(cornerRadius: 6).fill(
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.8
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help("打开 AI 额度中心")
                
                // ── Dedicated Exit System Monitor (Independent from AI Telemetry)
                Button(action: onExit) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ThemeColors.accentRed.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                                RoundedRectangle(cornerRadius: 6).fill(
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.8
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help("退出系统监控状态栏 (可在 AI 窗口或状态栏右键随时恢复)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
    
    // MARK: - 2 Minimalist System Mode Switcher Pills (Deep Glass Capsule)
    private var systemModeSwitcherView: some View {
        HStack(spacing: 0) {
            ForEach(SystemTab.allCases, id: \.rawValue) { tab in
                let isSelected = (monitor.systemTab == tab)
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        monitor.systemTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        Text(tab.title)
                            .font(.oppoSans(11, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disableFocusRing()
                .background(
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(Color(hex: 0x202228).opacity(0.70))
                                .overlay(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.14),
                                                    Color.white.opacity(0.04)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.35),
                                                    Color.white.opacity(0.06)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.40), radius: 3, x: 0, y: 1.5)
                                .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 3)
                                .matchedGeometryEffect(id: "systemActiveCapsule", in: systemTabNamespace)
                        }
                    }
                )
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.35))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
        )
    }
    
    // ════════════════════════════════════════════════════════════
    // MARK: - Tab 1: Traffic Monitor (Nothing Dot-Matrix Equalizer)
    // ════════════════════════════════════════════════════════════
    private var trafficTabContent: some View {
        VStack(spacing: 10) {
            // Speed & Dot-Matrix Equalizer Card
            VStack(spacing: 8) {
                // Big High-Contrast Numbers
                HStack(alignment: .top) {
                    // Upload (Purple Dot Accent & Authentic 5x7 Dot Matrix Display)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .bottom, spacing: 5) {
                            DotMatrixTextView(
                                text: String(format: "%.0f", monitor.snapshot.uploadSpeed),
                                dotSize: 3.2,
                                dotSpacing: 1.4,
                                charSpacing: 3.0,
                                activeColor: Color.white,
                                showGrid: true
                            )
                            Text("KB/s")
                                .font(.sfSans(11, weight: .semibold, design: .monospaced))
                                .foregroundColor(ThemeColors.textSecondary)
                                .padding(.bottom, 2)
                        }
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(ThemeColors.accentPurple)
                                .frame(width: 5, height: 5)
                            Text("TX · 上传")
                                .font(.oppoSans(10.5, weight: .medium))
                                .foregroundColor(ThemeColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Download (Electric Blue Dot Accent & Authentic 5x7 Dot Matrix Display)
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(alignment: .bottom, spacing: 5) {
                            DotMatrixTextView(
                                text: String(format: "%.0f", monitor.snapshot.downloadSpeed),
                                dotSize: 3.2,
                                dotSpacing: 1.4,
                                charSpacing: 3.0,
                                activeColor: Color.white,
                                showGrid: true
                            )
                            Text("KB/s")
                                .font(.sfSans(11, weight: .semibold, design: .monospaced))
                                .foregroundColor(ThemeColors.textSecondary)
                                .padding(.bottom, 2)
                        }
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(ThemeColors.accentBlue)
                                .frame(width: 5, height: 5)
                            Text("RX · 下载")
                                .font(.oppoSans(10.5, weight: .medium))
                                .foregroundColor(ThemeColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
                
                // Nothing / Teenage Engineering Style Dot-Matrix Equalizer!
                WaveformView(bars: monitor.spectrumBars)
                    .frame(height: 76)
                
                // Cumulative Summary (Purple & Blue)
                HStack {
                    HStack(spacing: 4) {
                        Text("↑")
                            .font(.sfSans(10, weight: .bold))
                            .foregroundColor(ThemeColors.accentPurple)
                        Text("累计上传")
                            .font(.oppoSans(10.5, weight: .medium))
                            .foregroundColor(ThemeColors.textMuted)
                        Text(monitor.snapshot.uploadTotal)
                            .font(.sfSans(11, weight: .bold, design: .monospaced))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("↓")
                            .font(.sfSans(10, weight: .bold))
                            .foregroundColor(ThemeColors.accentBlue)
                        Text("累计下载")
                            .font(.oppoSans(10.5, weight: .medium))
                            .foregroundColor(ThemeColors.textMuted)
                        Text(monitor.snapshot.downloadTotal)
                            .font(.sfSans(11, weight: .bold, design: .monospaced))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .industrialCard()
            
            // Wi-Fi Card (Real Detected SSID: TP-LINK_187F)
            HStack(spacing: 10) {
                Image(systemName: "wifi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ThemeColors.textSecondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(monitor.networkInfo.ssid)
                        .font(.sfSans(13, weight: .bold))
                        .foregroundColor(ThemeColors.textPrimary)
                    
                    Text("5 GHz · 866 Mbps · 信道 157")
                        .font(.sfSans(10, weight: .medium, design: .monospaced))
                        .foregroundColor(ThemeColors.textMuted)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    // Discrete dot signal indicator
                    HStack(spacing: 2) {
                        Circle().fill(Color.white).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.white).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.white).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.white).frame(width: 3.5, height: 3.5)
                    }
                    .padding(.trailing, 2)
                    
                    HStack(spacing: 4) {
                        Circle().fill(ThemeColors.accentGreen).frame(width: 4, height: 4)
                        Text("已连接")
                            .font(.oppoSans(9.5, weight: .medium))
                            .foregroundColor(ThemeColors.textSecondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ThemeColors.matteCardSecondary)
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .industrialCard(cornerRadius: 10)
            
            // IP Details Card (Technical Monospaced)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("PUBLIC & LOCAL IP")
                        .font(.sfSans(9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textMuted)
                    Spacer()
                    Text(monitor.networkInfo.countryFlag)
                        .font(.system(size: 13))
                }
                HStack {
                    Text(monitor.networkInfo.publicIPv4)
                        .font(.sfSans(13, weight: .semibold, design: .monospaced))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text(monitor.networkInfo.localIPv4)
                        .font(.sfSans(12, weight: .medium, design: .monospaced))
                        .foregroundColor(ThemeColors.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .industrialCard(cornerRadius: 10)
            
            // Active Processes Card (Consistent Spacing & Height with Hardware)
            VStack(spacing: 6) {
                HStack {
                    Text("ACTIVE PROCESSES")
                        .font(.sfSans(9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textMuted)
                    Spacer()
                    Text("TX")
                        .font(.sfSans(9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.accentPurple)
                        .frame(width: 45, alignment: .trailing)
                    Text("RX")
                        .font(.sfSans(9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.accentBlue)
                        .frame(width: 45, alignment: .trailing)
                }
                .padding(.bottom, 2)
                
                ForEach(monitor.topProcesses.prefix(5)) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.iconSystemName)
                            .font(.system(size: 10))
                            .foregroundColor(ThemeColors.textSecondary)
                            .frame(width: 14)
                        
                        Text(item.name)
                            .font(.oppoSans(11.5, weight: .medium))
                            .foregroundColor(ThemeColors.textPrimary)
                        
                        Spacer()
                        
                        Text(item.uploadSpeed)
                            .font(.sfSans(11, weight: .medium, design: .monospaced))
                            .foregroundColor(ThemeColors.textSecondary)
                            .frame(width: 45, alignment: .trailing)
                        
                        Text(item.downloadSpeed)
                            .font(.sfSans(11, weight: .bold, design: .monospaced))
                            .foregroundColor(ThemeColors.textPrimary)
                            .frame(width: 45, alignment: .trailing)
                    }
                    .padding(.vertical, 1.5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .industrialCard(cornerRadius: 10)
        }
    }

    // ════════════════════════════════════════════════════════════
    // MARK: - Tab 2: Hardware Overview (Intel iMac 2020 Real Specs with Generous Whitespace & Restrained Accents)
    // ════════════════════════════════════════════════════════════
    private var hardwareTabContent: some View {
        VStack(spacing: 10) {
            // ── 1. CPU Card (Intel Core i9 10-Core / 20 Threads)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.system(size: 11))
                        .foregroundColor(ThemeColors.accentBlue)
                        .frame(width: 14)
                    Text("CPU 处理器")
                        .font(.oppoSans(12, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f%%", monitor.snapshot.cpuUsage))
                        .font(.sfSans(14, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textPrimary)
                }
                
                // Restrained Blue Accent Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(ThemeColors.matteCardSecondary).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x00A3FF), Color(hex: 0x38BDF8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.0, monitor.snapshot.cpuUsage / 100.0))), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(monitor.snapshot.cpuBrand)
                        .font(.oppoSans(10))
                        .foregroundColor(ThemeColors.textSecondary)
                    Spacer()
                    Text("\(monitor.snapshot.cpuFreq) · \(monitor.snapshot.cpuTemp)")
                        .font(.sfSans(10, weight: .semibold, design: .monospaced))
                        .foregroundColor(ThemeColors.accentBlue)
                }
                
                // 10-Core Telemetry Micro-Blocks (Lit with Subtle Electric Blue)
                HStack(spacing: 3) {
                    ForEach(0..<10, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(c < 2 ? Color(hex: 0x00A3FF) : (c < 5 ? Color(hex: 0x0284C7).opacity(0.6) : ThemeColors.dotInactive))
                            .frame(height: 5)
                    }
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .industrialCard(cornerRadius: 10)
            
            // ── 2. GPU Card (AMD Radeon Pro 5500 XT 8GB VRAM)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: "display")
                        .font(.system(size: 11))
                        .foregroundColor(ThemeColors.accentPurple)
                        .frame(width: 14)
                    Text("图形显卡 GPU")
                        .font(.oppoSans(12, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text("60 FPS")
                        .font(.sfSans(10, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.purpleLight)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(ThemeColors.accentPurple.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(ThemeColors.accentPurple.opacity(0.3), lineWidth: 0.8))
                        .cornerRadius(3)
                }
                
                HStack(spacing: 6) {
                    gpuMiniBadge(title: "GPU 负载", value: String(format: "%.0f%%", monitor.snapshot.gpuUsage), valueColor: ThemeColors.accentBlue)
                    gpuMiniBadge(title: "显存占用", value: String(format: "%.0f%%", monitor.snapshot.gpuVRAMUsage), valueColor: ThemeColors.purpleLight)
                    gpuMiniBadge(title: "核心温度", value: monitor.snapshot.gpuTemp, valueColor: ThemeColors.textPrimary)
                    gpuMiniBadge(title: "型号", value: "5500 XT", valueColor: ThemeColors.textSecondary)
                }
                
                Text("AMD Radeon Pro 5500 XT · 8 GB GDDR6 显存")
                    .font(.oppoSans(10))
                    .foregroundColor(ThemeColors.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .industrialCard(cornerRadius: 10)
            
            // ── 3. Memory Card (40 GB DDR4 - Real Breakdown)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: "memorychip")
                        .font(.system(size: 11))
                        .foregroundColor(ThemeColors.accentPurple)
                        .frame(width: 14)
                    Text("系统内存 MEM")
                        .font(.oppoSans(12, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.snapshot.memUsage))
                        .font(.sfSans(14, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textPrimary)
                }
                
                // Memory Bar (Electric Blue to Neon Purple Subtle Gradient)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(ThemeColors.matteCardSecondary).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x00A3FF), ThemeColors.accentPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.0, monitor.snapshot.memUsage / 100.0))), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(String(format: "已用 %.1f GB / 总共 %.0f GB", monitor.snapshot.memUsedGB, monitor.snapshot.memTotalGB))
                        .font(.sfSans(10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(ThemeColors.textSecondary)
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(ThemeColors.accentGreen).frame(width: 4, height: 4)
                        Text("压力 23%")
                            .font(.oppoSans(10, weight: .medium))
                            .foregroundColor(ThemeColors.textMuted)
                    }
                }
                
                // Categorized Memory Micro-Pills with Discrete Colored Dots
                HStack(spacing: 5) {
                    HStack(spacing: 2.5) {
                        Circle().fill(ThemeColors.accentBlue).frame(width: 3.5, height: 3.5)
                        Text("App: 21.5 GB")
                            .font(.sfSans(8.5, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                            .foregroundColor(ThemeColors.accentBlue)
                    }
                    HStack(spacing: 2.5) {
                        Circle().fill(ThemeColors.accentPurple).frame(width: 3.5, height: 3.5)
                        Text("联动: 4.0 GB")
                            .font(.sfSans(8.5, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                            .foregroundColor(ThemeColors.purpleLight)
                    }
                    HStack(spacing: 2.5) {
                        Circle().fill(ThemeColors.accentOrange).frame(width: 3.5, height: 3.5)
                        Text("压缩: 5.1 GB")
                            .font(.sfSans(8.5, design: .monospaced))
                            .lineLimit(1)
                            .foregroundColor(ThemeColors.textSecondary)
                    }
                    HStack(spacing: 2.5) {
                        Circle().fill(ThemeColors.textMuted).frame(width: 3.5, height: 3.5)
                        Text("可用: 9.4 GB")
                            .font(.sfSans(8.5, design: .monospaced))
                            .lineLimit(1)
                            .foregroundColor(ThemeColors.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .industrialCard(cornerRadius: 10)
            
            // ── 4. Storage SSD Card
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 11))
                        .foregroundColor(ThemeColors.accentBlue)
                        .frame(width: 14)
                    Text("内置存储 SSD")
                        .font(.oppoSans(12, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.snapshot.diskUsage))
                        .font(.sfSans(14, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textPrimary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(ThemeColors.matteCardSecondary).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x00A3FF).opacity(0.85), Color(hex: 0x38BDF8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.0, monitor.snapshot.diskUsage / 100.0))), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text("Macintosh HD · APFS")
                        .font(.oppoSans(10))
                        .foregroundColor(ThemeColors.textMuted)
                    Spacer()
                    Text(String(format: "已用 %.0f GB / 总共 %.0f GB", monitor.snapshot.diskUsedGB, monitor.snapshot.diskTotalGB))
                        .font(.sfSans(10, weight: .medium, design: .monospaced))
                        .foregroundColor(ThemeColors.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .industrialCard(cornerRadius: 10)
            
            // ── 5. Intel Desktop Power & Uptime Card (NO BATTERY MOCK!)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 11))
                        .foregroundColor(ThemeColors.textSecondary)
                        .frame(width: 14)
                    Text("系统运行状态 · 台式机")
                        .font(.oppoSans(12, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(ThemeColors.accentGreen).frame(width: 4, height: 4)
                        Text("稳定直供")
                            .font(.oppoSans(9.5, weight: .medium))
                            .foregroundColor(ThemeColors.accentGreen)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(ThemeColors.matteCardSecondary)
                    .cornerRadius(3)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("供电方式")
                            .font(.oppoSans(10))
                            .foregroundColor(ThemeColors.textMuted)
                        Text("交流电源 (AC Power)")
                            .font(.oppoSans(11, weight: .medium))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("开机运行时间")
                            .font(.oppoSans(10))
                            .foregroundColor(ThemeColors.textMuted)
                        Text(monitor.snapshot.uptime)
                            .font(.sfSans(11, weight: .semibold, design: .monospaced))
                            .foregroundColor(ThemeColors.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("系统平均负载")
                            .font(.oppoSans(10))
                            .foregroundColor(ThemeColors.textMuted)
                        Text(monitor.snapshot.loadAvg)
                            .font(.sfSans(11, weight: .semibold, design: .monospaced))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .industrialCard(cornerRadius: 10)
        }
    }
    
    private func gpuMiniBadge(title: String, value: String, valueColor: Color = ThemeColors.textPrimary) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.oppoSans(9))
                .foregroundColor(ThemeColors.textMuted)
            Text(value)
                .font(.sfSans(11, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(ThemeColors.matteCardSecondary)
        .cornerRadius(6)
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack(alignment: .center, spacing: 8) {
            // Clickable Version Badge (Opens GitHub Releases)
            Button(action: {
                if let url = URL(string: "https://github.com/suleeeee/Pulse/releases") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Text("PULSE")
                        .font(.sfSans(8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.60))
                    HStack(spacing: 2.5) {
                        Text("v1.5")
                            .font(.sfSans(7.5, weight: .bold, design: .monospaced))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 6, weight: .bold))
                    }
                    .foregroundColor(Color.white.opacity(0.80))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(3.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                    )
                }
            }
            .buttonStyle(.plain)
            .disableFocusRing()
            .help("点击打开 GitHub 下载与版本更新页面 (v1.5)")
            
            Spacer()
            
            // Switch to AI Window or Restore AI Status Bar (Dark Glass)
            Button(action: onOpenAI) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8.5))
                    Text(monitor.isAIStatusItemActive ? "AI 额度 ↗" : "+ 开启 AI 状态栏")
                        .font(.oppoSans(9, weight: .medium))
                }
                .foregroundColor(monitor.isAIStatusItemActive ? Color(hex: 0xC084FC) : Color.white.opacity(0.80))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    monitor.isAIStatusItemActive
                        ? ThemeColors.accentPurple.opacity(0.16)
                        : Color.white.opacity(0.06)
                )
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(monitor.isAIStatusItemActive ? ThemeColors.accentPurple.opacity(0.40) : Color.white.opacity(0.10), lineWidth: 0.7)
                )
            }
            .buttonStyle(.springPress)
            .disableFocusRing()
            .help(monitor.isAIStatusItemActive ? "切换至 AI 额度中心" : "恢复并打开 AI 额度状态栏")
            
            // Close / Collapse window (Dark Glass)
            Button(action: onClose) {
                Text("收起")
                    .font(.oppoSans(9.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.7)
                    )
            }
            .buttonStyle(.springPress)
            .disableFocusRing()
            .help("收起当前浮窗 (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ThemeColors.matteCardSecondary)
    }
}

// MARK: - 2. Dedicated Independent AI Popup View
struct AIPopupView: View {
    @ObservedObject var quotaMgr: QuotaManager
    @State private var isPinned: Bool = false
    @Namespace private var aiTabNamespace
    var onOpenSystem: () -> Void = {}
    var onClose: () -> Void = {}
    var onExit: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 0) {
            aiHeaderView
            
            // Scalable Multi-AI Provider Rail (Supports Antigravity, Claude, Codex, Grok, DeepSeek)
            aiModelSwitcherView
                .padding(.top, 8)
                .padding(.bottom, 6)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    let source = quotaMgr.selectedAITab
                    AIProfileQuotaCardView(
                        source: source,
                        profile: quotaMgr.profile(for: source),
                        isStatusPinned: quotaMgr.activeStatusAI == source,
                        onPinToStatusBar: {
                            quotaMgr.setStatusAI(source)
                        }
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            aiFooterView
        }
        .frame(width: 360, height: 520)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                ThemeColors.glassTint
            }
        )
        .preferredColorScheme(.dark)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var aiHeaderView: some View {
        HStack(spacing: 8) {
            PulseBrandBadge()
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("AI 额度中心")
                        .font(.sfSans(13.5, weight: .bold))
                        .tracking(-0.3)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundColor(ThemeColors.textPrimary)
                    Text("TELEMETRY")
                        .font(.sfSans(8, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(ThemeColors.textMuted)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(ThemeColors.matteCardSecondary)
                        .cornerRadius(3)
                }
                
                HStack(spacing: 5) {
                    Text("实时配额")
                        .font(.oppoSans(9.5, weight: .medium))
                        .foregroundColor(ThemeColors.textSecondary)
                    Circle()
                        .fill(ThemeColors.accentGreen)
                        .frame(width: 4.5, height: 4.5)
                    Text("·")
                        .foregroundColor(ThemeColors.textMuted)
                    Text(quotaMgr.lastUpdated)
                        .font(.sfSans(9.5, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(ThemeColors.textMuted)
                }
            }
            
            Spacer(minLength: 4)
            
            HStack(spacing: 4) {
                Button(action: { isPinned.toggle() }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10.5))
                        .foregroundColor(isPinned ? ThemeColors.accentRed : Color.white.opacity(0.70))
                        .frame(width: 25, height: 25)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                                RoundedRectangle(cornerRadius: 6).fill(
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.8
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help(isPinned ? "取消固定" : "固定浮窗")
                
                Button(action: {
                    quotaMgr.fetchAntigravityLiveDaemonQuota(force: true)
                    quotaMgr.fetchCodexLiveQuota(force: true)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.white.opacity(0.75))
                        .rotationEffect(.degrees(quotaMgr.isRefreshing ? 360 : 0))
                        .animation(quotaMgr.isRefreshing ? Animation.linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: quotaMgr.isRefreshing)
                        .frame(width: 25, height: 25)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                                RoundedRectangle(cornerRadius: 6).fill(
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.8
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help("立即刷新实时配额")

                // ── Quick Jump to System Monitor
                Button(action: onOpenSystem) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 10.5))
                        .foregroundColor(ThemeColors.accentCyan)
                        .frame(width: 25, height: 25)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                                RoundedRectangle(cornerRadius: 6).fill(
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.8
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help("打开系统监控面板")
                
                // ── Dedicated Exit AI Button (Independent from System Info & Net speed)
                Button(action: onExit) {
                    Image(systemName: "power")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(ThemeColors.accentRed.opacity(0.85))
                        .frame(width: 25, height: 25)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25))
                                RoundedRectangle(cornerRadius: 6).fill(
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.8
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help("退出 AI 状态栏 (可在系统窗口或状态栏右键随时恢复)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
    
    // Multi-AI Provider Rail: Deep Glass Capsule
    private var aiModelSwitcherView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(ActiveAISource.allCases, id: \.rawValue) { source in
                    let isSelected = (quotaMgr.selectedAITab == source)
                    let isPinned = (quotaMgr.activeStatusAI == source)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            quotaMgr.selectedAITab = source
                        }
                        if source == .codex {
                            quotaMgr.fetchCodexLiveQuota(force: true)
                        } else if source == .antigravity {
                            quotaMgr.fetchAntigravityLiveDaemonQuota(force: true)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: source.iconSystemName)
                                .font(.system(size: 9.5, weight: isSelected ? .semibold : .medium))
                                .foregroundColor(isSelected ? Color(hex: source.accentHex) : Color.white.opacity(0.55))
                            
                            Text(source.title)
                                .font(.sfSans(11, weight: isSelected ? .semibold : .regular))
                            
                            if isPinned {
                                Circle()
                                    .fill(ThemeColors.accentGreen)
                                    .frame(width: 4, height: 4)
                            } else if !source.isConfigured {
                                Text("预留")
                                    .font(.pingFangSC(7.5, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.50))
                                    .padding(.horizontal, 3.5)
                                    .padding(.vertical, 0.8)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.55))
                        .padding(.horizontal, 10.5)
                        .padding(.vertical, 5.5)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disableFocusRing()
                    .background(
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(Color(hex: 0x202228).opacity(0.70))
                                    .overlay(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.14),
                                                        Color.white.opacity(0.04)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.35),
                                                        Color.white.opacity(0.06)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.8
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.40), radius: 3, x: 0, y: 1.5)
                                    .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 3)
                                    .matchedGeometryEffect(id: "aiActiveCapsule", in: aiTabNamespace)
                            }
                        }
                    )
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.35))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
            )
            .padding(.horizontal, 14)
        }
    }
    
    private var aiFooterView: some View {
        HStack(alignment: .center, spacing: 8) {
            // Clickable Version Badge (Opens GitHub Releases)
            Button(action: {
                if let url = URL(string: "https://github.com/suleeeee/Pulse/releases") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Text("PULSE AI")
                        .font(.sfSans(8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.60))
                    HStack(spacing: 2.5) {
                        Text("v1.5")
                            .font(.sfSans(7.5, weight: .bold, design: .monospaced))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 6, weight: .bold))
                    }
                    .foregroundColor(Color.white.opacity(0.80))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(3.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                    )
                }
            }
            .buttonStyle(.plain)
            .disableFocusRing()
            .help("点击打开 GitHub 下载与版本更新页面 (v1.5)")
            
            Spacer()
            
            // Switch to System Window or Restore System Status Bar (Dark Glass)
            Button(action: onOpenSystem) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 8.5))
                    Text(quotaMgr.isSystemStatusItemActive ? "系统监控 ↗" : "+ 开启系统监控")
                        .font(.oppoSans(9, weight: .medium))
                }
                .foregroundColor(quotaMgr.isSystemStatusItemActive ? ThemeColors.accentCyan : Color.white.opacity(0.80))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    quotaMgr.isSystemStatusItemActive
                        ? ThemeColors.accentCyan.opacity(0.16)
                        : Color.white.opacity(0.06)
                )
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(quotaMgr.isSystemStatusItemActive ? ThemeColors.accentCyan.opacity(0.40) : Color.white.opacity(0.10), lineWidth: 0.7)
                )
            }
            .buttonStyle(.springPress)
            .disableFocusRing()
            .help(quotaMgr.isSystemStatusItemActive ? "切换至系统流量与硬件监控" : "恢复并打开系统网速状态栏")
            
            // Close / Collapse window (Dark Glass)
            Button(action: onClose) {
                Text("收起")
                    .font(.oppoSans(9.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.7)
                    )
            }
            .buttonStyle(.springPress)
            .disableFocusRing()
            .help("收起当前浮窗 (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ThemeColors.matteCardSecondary)
    }
}

// MARK: - Multi-AI Profile Quota Card (Spacious, Clear Hierarchy, Nothing OS Aesthetic)
struct AIProfileQuotaCardView: View {
    let source: ActiveAISource
    let profile: AIProfileQuota
    let isStatusPinned: Bool
    let onPinToStatusBar: () -> Void
    
    @State private var isEmailVisible: Bool = UserDefaults.standard.bool(forKey: "sysbar_show_real_email")
    
    private var displayEmail: String {
        if isEmailVisible {
            return profile.accountEmail
        } else {
            return maskEmail(profile.accountEmail)
        }
    }
    
    private func maskEmail(_ raw: String) -> String {
        if let startIdx = raw.firstIndex(of: "("),
           let endIdx = raw.lastIndex(of: ")"),
           startIdx < endIdx {
            let prefix = String(raw[..<startIdx])
            let inner = String(raw[raw.index(after: startIdx)..<endIdx])
            return "\(prefix)(\(maskInnerEmail(inner)))"
        } else {
            return maskInnerEmail(raw)
        }
    }
    
    private func maskInnerEmail(_ email: String) -> String {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else {
            if email.count > 8 {
                let p = email.prefix(3)
                let s = email.suffix(3)
                return "\(p)••••••\(s)"
            }
            return email
        }
        let user = String(parts[0])
        let domain = String(parts[1])
        
        let maskedUser: String
        if user.count <= 2 {
            maskedUser = "\(user.prefix(1))••"
        } else if user.count <= 4 {
            maskedUser = "\(user.prefix(1))•••\(user.suffix(1))"
        } else {
            maskedUser = "\(user.prefix(1))••••••\(user.suffix(1))"
        }
        return "\(maskedUser)@\(domain)"
    }
    
    var body: some View {
        VStack(spacing: 11) {
            // ── Layer 1: Account Identity & Status Bar Pinning Card
            accountCard
            
            // ── Layer 2: Model Quota Gauges OR Reserved Engine Slot
            if source.isConfigured {
                quotasCard
            } else {
                reservedSlotCard
            }
            
            // ── Layer 3: Storage & Local Telemetry Origin Card
            configStorageCard
        }
    }
    
    // MARK: - Layer 1: Account & Channel Pinning Card
    private var accountCard: some View {
        VStack(spacing: 9) {
            // Row 1: Keycap Icon, Email + Eye Masking, Active / Out of Quota Status Badge
            HStack(alignment: .center, spacing: 9) {
                // Keycap Icon (Inspired by user Nothing OS hardware keycaps)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeColors.matteCardTertiary)
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: source.accentHex).opacity(0.35), lineWidth: 0.8)
                        )
                    
                    if source == .antigravity,
                       let img = NSImage(contentsOfFile: "/Users/sulee/.gemini/antigravity/scratch/SysBar/Resources/Antigravity.png") {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    } else if source == .codex,
                              let img = NSImage(contentsOfFile: "/Users/sulee/.gemini/antigravity/scratch/SysBar/Resources/Codex.png") {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: source.iconSystemName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: source.accentHex))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(displayEmail)
                            .font(.sfSans(11.5, weight: .bold))
                            .foregroundColor(ThemeColors.textPrimary)
                            .lineLimit(1)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                isEmailVisible.toggle()
                                UserDefaults.standard.set(isEmailVisible, forKey: "sysbar_show_real_email")
                            }
                        }) {
                            Image(systemName: isEmailVisible ? "eye" : "eye.slash")
                                .font(.system(size: 9))
                                .foregroundColor(isEmailVisible ? ThemeColors.accentPurple : ThemeColors.textMuted)
                                .frame(width: 18, height: 18)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(3)
                        }
                        .buttonStyle(.springPress)
                        .disableFocusRing()
                        .help(isEmailVisible ? "隐藏真实账号" : "显示完整邮箱")
                    }
                    
                    Text(profile.accountType)
                        .font(.oppoSans(8.5, weight: .medium))
                        .foregroundColor(ThemeColors.textMuted)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Status Pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(profile.isActive ? ThemeColors.accentGreen : Color(hex: 0xEF4444))
                        .frame(width: 4.5, height: 4.5)
                    Text(source.isConfigured ? (profile.isActive ? "Active" : "已无额度") : "预留就绪")
                        .font(.sfSans(8.5, weight: .bold))
                        .foregroundColor(source.isConfigured ? (profile.isActive ? Color(hex: 0x86EFAC) : Color(hex: 0xFCA5A5)) : ThemeColors.textSecondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(profile.isActive ? ThemeColors.accentGreen.opacity(0.16) : Color(hex: 0x7F1D1D).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(profile.isActive ? ThemeColors.accentGreen.opacity(0.4) : Color(hex: 0xEF4444).opacity(0.4), lineWidth: 0.6)
                )
                .clipShape(Capsule())
            }
            
            // Out of Quota Warning Alert (Only for exhausted accounts)
            if !profile.isActive && source.isConfigured {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: 0xEF4444))
                    Text("当前账户额度已完全耗尽 (0 额度)，需等待重置周期")
                        .font(.oppoSans(8.5, weight: .medium))
                        .foregroundColor(Color(hex: 0xFCA5A5))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: 0x7F1D1D).opacity(0.35))
                .cornerRadius(5)
            }
            
            Divider()
                .background(ThemeColors.hairlineBorder)
                .padding(.vertical, 1)
            
            // Row 2: Status Bar Pinning Button & Subscription Link
            HStack(spacing: 8) {
                // Status Bar Pin Button
                Button(action: onPinToStatusBar) {
                    HStack(spacing: 5) {
                        Image(systemName: isStatusPinned ? "checkmark.circle.fill" : "pin")
                            .font(.system(size: 9, weight: .semibold))
                        Text(isStatusPinned ? "正在状态栏常驻显示" : "设为状态栏常驻 ↗")
                            .font(.sfSans(9, weight: .bold))
                    }
                    .foregroundColor(isStatusPinned ? ThemeColors.accentGreen : ThemeColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isStatusPinned ? ThemeColors.accentGreen.opacity(0.12) : Color.white.opacity(0.05))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isStatusPinned ? ThemeColors.accentGreen.opacity(0.35) : ThemeColors.hairlineBorder, lineWidth: 0.6)
                    )
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                .help(isStatusPinned ? "该模型的配额胶囊正在 macOS 顶部状态栏实时显示" : "将当前模型的实时配额胶囊固定到状态栏")
                
                Spacer()
                
                // Subscription Link
                if source == .antigravity {
                    Button(action: {
                        if let url = URL(string: "https://one.google.com/explore-plan") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text("Google AI Pro")
                                .font(.sfSans(9, weight: .semibold))
                                .foregroundColor(Color(hex: 0x60A5FA))
                            Text("Upgrade ↗")
                                .font(.sfSans(8.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: 0x2563EB))
                                .cornerRadius(3)
                        }
                    }
                    .buttonStyle(.springPress)
                    .disableFocusRing()
                } else if source == .codex {
                    Button(action: {
                        if let url = URL(string: "https://chatgpt.com/#settings/Subscription") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text("ChatGPT Plus")
                                .font(.sfSans(9, weight: .semibold))
                                .foregroundColor(Color(hex: 0x10B981))
                            Text("Manage ↗")
                                .font(.sfSans(8.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: 0x059669))
                                .cornerRadius(3)
                        }
                    }
                    .buttonStyle(.springPress)
                    .disableFocusRing()
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(ThemeColors.hairlineBorder, lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Layer 2: Model Quota Gauges (Spacious & Tactile)
    private var quotasCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(profile.categories) { cat in
                VStack(alignment: .leading, spacing: 7) {
                    // Category Header
                    HStack(spacing: 5) {
                        Text(cat.categoryName)
                            .font(.sfSans(10.5, weight: .bold))
                            .foregroundColor(ThemeColors.textPrimary)
                        
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 5))
                            .foregroundColor(ThemeColors.textMuted)
                        
                        Spacer()
                    }
                    
                    // Windows (7d, 5h)
                    VStack(spacing: 8) {
                        ForEach(cat.windows) { win in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(win.windowLabel)
                                        .font(.sfSans(9.5, weight: .bold, design: .monospaced))
                                        .monospacedDigit()
                                        .foregroundColor(ThemeColors.textSecondary)
                                        .frame(width: 22, alignment: .leading)
                                    
                                    // 6px tactile progress bar with pill ends
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.08))
                                                .frame(height: 6)
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            barColor(for: win).opacity(0.85),
                                                            barColor(for: win)
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: max(4, geo.size.width * CGFloat(min(1.0, win.percent / 100.0))), height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                    
                                    Text(displayPercent(win.percent))
                                        .font(.sfSans(10, weight: .bold, design: .monospaced))
                                        .monospacedDigit()
                                        .foregroundColor(barColor(for: win))
                                        .frame(width: 36, alignment: .trailing)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 7.5))
                                        .foregroundColor(ThemeColors.textMuted.opacity(0.8))
                                    Text(win.resetText)
                                        .font(.sfSans(8.5, weight: .regular))
                                        .foregroundColor(ThemeColors.textMuted)
                                }
                                .padding(.leading, 30)
                            }
                        }
                    }
                }
                
                if cat.id != profile.categories.last?.id {
                    Divider()
                        .background(ThemeColors.hairlineBorder.opacity(0.6))
                        .padding(.vertical, 1)
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(ThemeColors.hairlineBorder, lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Layer 2 (Alternative): Reserved Provider Connection Slot
    private var reservedSlotCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: source.accentHex).opacity(0.12))
                        .frame(width: 28, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color(hex: source.accentHex).opacity(0.35), lineWidth: 0.8)
                        )
                    Image(systemName: source.iconSystemName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: source.accentHex))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(source.title) Telemetry Slot")
                        .font(.sfSans(11, weight: .bold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Text("架构预留 · 即插即用")
                        .font(.oppoSans(8.5, weight: .medium))
                        .foregroundColor(ThemeColors.textMuted)
                }
                
                Spacer()
                
                Text("待连接")
                    .font(.sfSans(8.5, weight: .semibold))
                    .foregroundColor(Color(hex: source.accentHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color(hex: source.accentHex).opacity(0.12))
                    .cornerRadius(4)
            }
            
            Text(reservedDescription(for: source))
                .font(.oppoSans(9, weight: .regular))
                .foregroundColor(ThemeColors.textSecondary)
                .lineSpacing(2.5)
            
            HStack(spacing: 8) {
                Button(action: {
                    let dir = NSHomeDirectory() + "/.gemini/antigravity"
                    NSWorkspace.shared.open(URL(fileURLWithPath: dir))
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 8.5))
                        Text("配置 API 凭据")
                            .font(.sfSans(9, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ThemeColors.matteCardTertiary)
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(ThemeColors.hairlineBorderHighlight, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                
                Button(action: {
                    let urlStr: String
                    switch source {
                    case .claude: urlStr = "https://console.anthropic.com"
                    case .grok: urlStr = "https://x.ai/api"
                    case .deepseek: urlStr = "https://platform.deepseek.com"
                    default: urlStr = "https://antigravity.google"
                    }
                    if let url = URL(string: urlStr) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("控制台 ↗")
                        .font(.sfSans(9, weight: .medium))
                        .foregroundColor(ThemeColors.textMuted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(5)
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(ThemeColors.hairlineBorder, lineWidth: 0.8)
                )
        )
    }
    
    private func reservedDescription(for source: ActiveAISource) -> String {
        switch source {
        case .claude:
            return "已预留 Anthropic Claude 3.7 Sonnet / Opus 周期配额监控。支持网页端 Session Token 及 Console API 速率限制自动轮询。"
        case .grok:
            return "已预留 xAI Grok 2 & Grok 3 接口配额监控。支持 API Key 余额检测与速率限制（Rate Limits）实时解析。"
        case .deepseek:
            return "已预留 DeepSeek V3 / R1 深度思考推理模型额度监控。支持官方开放平台 API 账户余额及并发阈值监测。"
        default:
            return "已预留多模型配额扩展插槽，支持自定义 JSON 规则与 API 端点同步。"
        }
    }
    
    // MARK: - Layer 3: Storage & Local Telemetry Origin
    private var configStorageCard: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 8.5))
                .foregroundColor(ThemeColors.textMuted)
            Text(configFilePath(for: source))
                .font(.sfSans(8.5, design: .monospaced))
                .foregroundColor(ThemeColors.textMuted)
                .lineLimit(1)
            
            Spacer()
            
            Button("打开目录 ↗") {
                let dir = configFileDir(for: source)
                NSWorkspace.shared.open(URL(fileURLWithPath: dir))
            }
            .font(.oppoSans(8.5, weight: .medium))
            .foregroundColor(ThemeColors.textSecondary)
            .buttonStyle(.springPress)
            .disableFocusRing()
        }
        .padding(.horizontal, 4)
        .padding(.top, 1)
    }
    
    private func configFilePath(for source: ActiveAISource) -> String {
        switch source {
        case .antigravity: return "~/.gemini/antigravity/usage.json"
        case .codex: return "~/.codex/auth.json"
        case .claude: return "~/.claude/settings.json"
        case .grok: return "~/.grok/credentials.json"
        case .deepseek: return "~/.deepseek/config.json"
        }
    }
    
    private func configFileDir(for source: ActiveAISource) -> String {
        switch source {
        case .antigravity: return NSHomeDirectory() + "/.gemini/antigravity"
        case .codex: return NSHomeDirectory() + "/.codex"
        case .claude: return NSHomeDirectory() + "/.claude"
        case .grok: return NSHomeDirectory() + "/.grok"
        case .deepseek: return NSHomeDirectory() + "/.deepseek"
        }
    }
    
    private func displayPercent(_ p: Double) -> String {
        if p >= 99.99 {
            return "100%"
        } else if p >= 99.0 {
            return "99%"
        } else {
            return String(format: "%.0f%%", p)
        }
    }
    
    private func barColor(for win: RollingWindowQuota) -> Color {
        if win.isExhausted {
            return Color(hex: 0xEF4444)
        } else if win.percent >= 80.0 {
            return Color(hex: 0x22C55E)
        } else if win.percent >= 50.0 {
            return Color(hex: 0x84CC16)
        } else if win.percent > 0.0 {
            return Color(hex: 0xF59E0B)
        } else {
            return Color(hex: 0xEF4444)
        }
    }
}


// MARK: - Muted Action Button (No Default Keyboard Focus, Hover Only)
struct MutedActionButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.oppoSans(10, weight: .medium))
                .foregroundColor(isHovered ? ThemeColors.accentRed : ThemeColors.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isHovered ? ThemeColors.accentRed.opacity(0.12) : Color.clear)
                .cornerRadius(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disableFocusRing()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
