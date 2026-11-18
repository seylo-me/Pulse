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
    let cwdFallback = FileManager.default.currentDirectoryPath + "/Resources/pulse_logo.svg"
    return NSImage(contentsOfFile: cwdFallback)
}

// MARK: - 1. System Popup View (Dedicated Traffic & Hardware - Zero AI Clutter!)
struct SystemPopupView: View {
    @ObservedObject var monitor: SystemMonitor
    @Namespace private var systemTabNamespace
    @State private var isCloseHovered: Bool = false
    
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
                .padding(.top, 4)
                .padding(.bottom, 6)
            
            // ── Main Content Tab Area (100% Fit in One Screen, No Scrolling)
            VStack(spacing: 0) {
                switch monitor.systemTab {
                case .traffic:
                    trafficTabContent
                case .hardware:
                    hardwareTabContent
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            
            Spacer(minLength: 4)
            
            // ── Industrial Footer
            footerView
        }
        .frame(width: 360, height: 535)
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
            
            VStack(alignment: .leading, spacing: 0) {
                // Row 1: Pulse logo (Enlarged SVG with crisp top-alignment)
                HStack(alignment: .center, spacing: 6) {
                    if let logo = loadPulseLogo() {
                        Image(nsImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 53.5, height: 14.5)
                    } else {
                        Text("PULSE")
                            .font(.sfSans(14, weight: .bold, design: .monospaced))
                            .tracking(-0.3)
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Row 2: ONLINE + red dot + IP (Flush bottom-aligned with icon badge)
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
                .offset(y: 5.5)
            }
            .frame(height: 32)
            
            Spacer(minLength: 8)
            
            // Action Button: Bare Power/Close SVG glyph (No outer box, soft gray -> vibrant red on hover)
            Button(action: onExit) {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isCloseHovered ? Color(hex: 0xEF4444) : Color.white.opacity(0.38))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disableFocusRing()
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isCloseHovered = hovering
                }
            }
            .help("退出系统监控状态栏")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
    
    // MARK: - 2 Minimalist System Mode Switcher Pills (Ultra-Refined Frosted Glass Capsule)
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
                            .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.48))
                        Text(tab.title)
                            .font(.sfSans(11, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.48))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5.5)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disableFocusRing()
                .background(
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.18),
                                            Color.white.opacity(0.06)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.50),
                                                    Color.white.opacity(0.12)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.75
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                                .matchedGeometryEffect(id: "systemActiveCapsule", in: systemTabNamespace)
                        }
                    }
                )
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.28))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
        )
    }
    
    // ════════════════════════════════════════════════════════════
    // MARK: - Tab 1: Traffic Monitor (Nothing Dot-Matrix Equalizer)
    // ════════════════════════════════════════════════════════════
    private var trafficTabContent: some View {
        VStack(spacing: 6) {
            // Speed & Dot-Matrix Equalizer Card
            VStack(spacing: 5) {
                // Big High-Contrast Numbers
                HStack(alignment: .top) {
                    // Upload (Purple Dot Accent & Authentic 5x7 Dot Matrix Display)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .bottom, spacing: 4) {
                            DotMatrixTextView(
                                text: String(format: "%.0f", monitor.snapshot.uploadSpeed),
                                dotSize: 2.8,
                                dotSpacing: 1.2,
                                charSpacing: 2.4,
                                activeColor: Color.white,
                                showGrid: true
                            )
                            Text("KB/s")
                                .font(.sfSans(10, weight: .semibold, design: .monospaced))
                                .foregroundColor(ThemeColors.textSecondary)
                                .padding(.bottom, 1.5)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ThemeColors.accentPurple)
                                .frame(width: 4.5, height: 4.5)
                            Text("TX · 上传")
                                .font(.oppoSans(10, weight: .medium))
                                .foregroundColor(ThemeColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Download (Electric Blue Dot Accent & Authentic 5x7 Dot Matrix Display)
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(alignment: .bottom, spacing: 4) {
                            DotMatrixTextView(
                                text: String(format: "%.0f", monitor.snapshot.downloadSpeed),
                                dotSize: 2.8,
                                dotSpacing: 1.2,
                                charSpacing: 2.4,
                                activeColor: Color.white,
                                showGrid: true
                            )
                            Text("KB/s")
                                .font(.sfSans(10, weight: .semibold, design: .monospaced))
                                .foregroundColor(ThemeColors.textSecondary)
                                .padding(.bottom, 1.5)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ThemeColors.accentBlue)
                                .frame(width: 4.5, height: 4.5)
                            Text("RX · 下载")
                                .font(.oppoSans(10, weight: .medium))
                                .foregroundColor(ThemeColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
                
                // Nothing / Teenage Engineering Style Dot-Matrix Equalizer (Zero Overlap Canvas)!
                WaveformView(bars: monitor.spectrumBars)
                
                // Cumulative Summary (Purple & Blue)
                HStack {
                    HStack(spacing: 4) {
                        Text("↑")
                            .font(.sfSans(9.5, weight: .bold))
                            .foregroundColor(ThemeColors.accentPurple)
                        Text("累计上传")
                            .font(.oppoSans(9.5, weight: .medium))
                            .foregroundColor(ThemeColors.textMuted)
                        Text(monitor.snapshot.uploadTotal)
                            .font(.sfSans(10.5, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("↓")
                            .font(.sfSans(9.5, weight: .bold))
                            .foregroundColor(ThemeColors.accentBlue)
                        Text("累计下载")
                            .font(.oppoSans(9.5, weight: .medium))
                            .foregroundColor(ThemeColors.textMuted)
                        Text(monitor.snapshot.downloadTotal)
                            .font(.sfSans(10.5, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .industrialCard(cornerRadius: 10)
            
            // Wi-Fi Card (Real Dynamically Detected SSID)
            HStack(spacing: 10) {
                Image(systemName: "wifi")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ThemeColors.textSecondary)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(monitor.networkInfo.ssid)
                        .font(.sfSans(12, weight: .bold))
                        .foregroundColor(ThemeColors.textPrimary)
                    
                    Text("5 GHz · 866 Mbps · 信道 157")
                        .font(.sfSans(9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(ThemeColors.textMuted)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    // Discrete dot signal indicator
                    HStack(spacing: 2) {
                        Circle().fill(Color.white).frame(width: 3, height: 3)
                        Circle().fill(Color.white).frame(width: 3, height: 3)
                        Circle().fill(Color.white).frame(width: 3, height: 3)
                        Circle().fill(Color.white).frame(width: 3, height: 3)
                    }
                    .padding(.trailing, 2)
                    
                    HStack(spacing: 3) {
                        Circle().fill(ThemeColors.accentGreen).frame(width: 3.5, height: 3.5)
                        Text("已连接")
                            .font(.oppoSans(9, weight: .medium))
                            .foregroundColor(ThemeColors.textSecondary)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(ThemeColors.matteCardSecondary)
                    .cornerRadius(3.5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .industrialCard(cornerRadius: 10)
            
            // IP Details Card (Clean Minimalist: Specific Proxy Details, Real IP under Proxy, Subdued Local IP)
            VStack(alignment: .leading, spacing: 3.5) {
                if monitor.networkInfo.isProxyActive {
                    // ── Proxy Egress IP (代理出口 + 详细地域节点描述)
                    HStack {
                        Text("PROXY IP · 代理出口")
                            .font(.sfSans(8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(ThemeColors.accentPurple)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(monitor.networkInfo.countryFlag)
                                .font(.system(size: 11))
                            Text(monitor.networkInfo.proxyLocation)
                                .font(.sfSans(9, weight: .medium, design: .monospaced))
                                .foregroundColor(ThemeColors.textSecondary)
                        }
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(monitor.networkInfo.publicIPv4)
                            .font(.sfSans(12.5, weight: .bold, design: .monospaced))
                            .foregroundColor(ThemeColors.textPrimary)
                        
                        Spacer()
                        
                        // 弱化本地内网 IP 显示 (Subdued Local LAN IP)
                        Text("内网: \(monitor.networkInfo.localIPv4)")
                            .font(.sfSans(8.5, weight: .regular, design: .monospaced))
                            .foregroundColor(ThemeColors.textMuted.opacity(0.65))
                    }
                    
                    // 仅需真实 IP 放代理 IP 下面 (Real Direct IP directly under Proxy IP)
                    if !monitor.networkInfo.directIPv4.isEmpty && monitor.networkInfo.directIPv4 != monitor.networkInfo.publicIPv4 {
                        HStack(spacing: 5) {
                            Text("真实 IP")
                                .font(.sfSans(8.5, weight: .bold, design: .monospaced))
                                .foregroundColor(ThemeColors.accentCyan)
                            Text(monitor.networkInfo.directIPv4)
                                .font(.sfSans(10, weight: .medium, design: .monospaced))
                                .foregroundColor(ThemeColors.textSecondary)
                            if !monitor.networkInfo.directCountryFlag.isEmpty && monitor.networkInfo.directCountryFlag != "🌐" {
                                Text(monitor.networkInfo.directCountryFlag)
                                    .font(.system(size: 9))
                            }
                        }
                        .padding(.top, 1)
                    }
                } else {
                    HStack {
                        Text("PUBLIC IP · 公网出口")
                            .font(.sfSans(8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(ThemeColors.textMuted)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(monitor.networkInfo.countryFlag)
                                .font(.system(size: 11))
                            Text(monitor.networkInfo.proxyLocation)
                                .font(.sfSans(9, weight: .medium, design: .monospaced))
                                .foregroundColor(ThemeColors.textSecondary)
                        }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(monitor.networkInfo.publicIPv4.isEmpty ? "--" : monitor.networkInfo.publicIPv4)
                            .font(.sfSans(12.5, weight: .bold, design: .monospaced))
                            .foregroundColor(ThemeColors.textPrimary)
                        Spacer()
                        // 弱化本地内网 IP 显示
                        Text("内网: \(monitor.networkInfo.localIPv4)")
                            .font(.sfSans(8.5, weight: .regular, design: .monospaced))
                            .foregroundColor(ThemeColors.textMuted.opacity(0.65))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .industrialCard(cornerRadius: 10)
            
            // Active Processes Card (Consistent Spacing & Height with Hardware)
            VStack(spacing: 4) {
                HStack {
                    Text("ACTIVE PROCESSES")
                        .font(.sfSans(9, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textMuted)
                    Spacer()
                    Text("TX")
                        .font(.sfSans(9, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.accentPurple)
                        .frame(width: 45, alignment: .trailing)
                    Text("RX")
                        .font(.sfSans(9, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.accentBlue)
                        .frame(width: 45, alignment: .trailing)
                }
                .padding(.bottom, 1)
                
                ForEach(monitor.topProcesses.prefix(4)) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.iconSystemName)
                            .font(.system(size: 9.5))
                            .foregroundColor(ThemeColors.textSecondary)
                            .frame(width: 13)
                        
                        Text(item.name)
                            .font(.oppoSans(11, weight: .medium))
                            .foregroundColor(ThemeColors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        processSpeedView(item.uploadSpeed, isBold: false, color: ThemeColors.textSecondary)
                        
                        processSpeedView(item.downloadSpeed, isBold: true, color: ThemeColors.textPrimary)
                    }
                    .padding(.vertical, 1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6.5)
            .industrialCard(cornerRadius: 10)
        }
    }
    
    // MARK: - Process Speed Label (Tight Single Space between Number and Unit, Tabular Digits)
    @ViewBuilder
    private func processSpeedView(_ speed: String, isBold: Bool, color: Color) -> some View {
        let clean = speed.replacingOccurrences(of: " ", with: "")
        let unit = String(clean.filter { $0.isLetter })
        let num = String(clean.filter { !$0.isLetter })
        
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(num)
                .font(.sfSans(isBold ? 10.5 : 10, weight: isBold ? .bold : .medium))
                .monospacedDigit()
            if !unit.isEmpty {
                Text(unit)
                    .font(.sfSans(isBold ? 9.5 : 9, weight: isBold ? .semibold : .medium))
            }
        }
        .foregroundColor(color)
        .frame(width: 45, alignment: .trailing)
    }

    // ════════════════════════════════════════════════════════════
    // MARK: - Tab 2: Hardware Overview (Intel iMac 2020 Real Specs with Generous Whitespace & Restrained Accents)
    // ════════════════════════════════════════════════════════════
    private var hardwareTabContent: some View {
        VStack(spacing: 5.5) {
            // ── 1. CPU Card (Intel Core i9 10-Core / 20 Threads)
            VStack(alignment: .leading, spacing: 4.5) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.system(size: 10.5))
                        .foregroundColor(ThemeColors.accentBlue)
                        .frame(width: 13)
                    Text("CPU 处理器")
                        .font(.oppoSans(11.5, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f%%", monitor.snapshot.cpuUsage))
                        .font(.sfSans(13, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textPrimary)
                }
                
                // Restrained Blue Accent Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(ThemeColors.matteCardSecondary).frame(height: 3.5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x00A3FF), Color(hex: 0x38BDF8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.0, monitor.snapshot.cpuUsage / 100.0))), height: 3.5)
                    }
                }
                .frame(height: 3.5)
                
                HStack {
                    Text(monitor.snapshot.cpuBrand)
                        .font(.oppoSans(9.5))
                        .foregroundColor(ThemeColors.textSecondary)
                    Spacer()
                    Text("\(monitor.snapshot.cpuFreq) · \(monitor.snapshot.cpuTemp)")
                        .font(.sfSans(9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(ThemeColors.accentBlue)
                }
                
                // 10-Core Telemetry Micro-Blocks (Lit with Subtle Electric Blue)
                HStack(spacing: 2.5) {
                    ForEach(0..<10, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(c < 2 ? Color(hex: 0x00A3FF) : (c < 5 ? Color(hex: 0x0284C7).opacity(0.6) : ThemeColors.dotInactive))
                            .frame(height: 4)
                    }
                }
                .padding(.top, 0.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6.5)
            .industrialCard(cornerRadius: 10)
            
            // ── 2. GPU Card (AMD Radeon Pro 5500 XT 8GB VRAM)
            VStack(alignment: .leading, spacing: 4.5) {
                HStack {
                    Image(systemName: "display")
                        .font(.system(size: 10.5))
                        .foregroundColor(ThemeColors.accentPurple)
                        .frame(width: 13)
                    Text("图形显卡 GPU")
                        .font(.oppoSans(11.5, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text("60 FPS")
                        .font(.sfSans(9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.purpleLight)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(ThemeColors.accentPurple.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(ThemeColors.accentPurple.opacity(0.3), lineWidth: 0.8))
                        .cornerRadius(3)
                }
                
                HStack(spacing: 5) {
                    gpuMiniBadge(title: "GPU 负载", value: String(format: "%.0f%%", monitor.snapshot.gpuUsage), valueColor: ThemeColors.accentBlue)
                    gpuMiniBadge(title: "显存占用", value: String(format: "%.0f%%", monitor.snapshot.gpuVRAMUsage), valueColor: ThemeColors.purpleLight)
                    gpuMiniBadge(title: "核心温度", value: monitor.snapshot.gpuTemp, valueColor: ThemeColors.textPrimary)
                    gpuMiniBadge(title: "型号", value: "5500 XT", valueColor: ThemeColors.textSecondary)
                }
                
                Text("AMD Radeon Pro 5500 XT · 8 GB GDDR6 显存")
                    .font(.oppoSans(9.5))
                    .foregroundColor(ThemeColors.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .industrialCard(cornerRadius: 10)
            
            // ── 3. Memory Card (40 GB DDR4 - Real Breakdown)
            VStack(alignment: .leading, spacing: 4.5) {
                HStack {
                    Image(systemName: "memorychip")
                        .font(.system(size: 10.5))
                        .foregroundColor(ThemeColors.accentPurple)
                        .frame(width: 13)
                    Text("系统内存 MEM")
                        .font(.oppoSans(11.5, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.snapshot.memUsage))
                        .font(.sfSans(13, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textPrimary)
                }
                
                // Memory Bar (Electric Blue to Neon Purple Subtle Gradient)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(ThemeColors.matteCardSecondary).frame(height: 3.5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x00A3FF), ThemeColors.accentPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.0, monitor.snapshot.memUsage / 100.0))), height: 3.5)
                    }
                }
                .frame(height: 3.5)
                
                HStack {
                    Text(String(format: "已用 %.1f GB / 总共 %.0f GB", monitor.snapshot.memUsedGB, monitor.snapshot.memTotalGB))
                        .font(.sfSans(10, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(ThemeColors.textSecondary)
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(ThemeColors.accentGreen).frame(width: 3.5, height: 3.5)
                        Text("压力 23%")
                            .font(.oppoSans(9.5, weight: .medium))
                            .foregroundColor(ThemeColors.textMuted)
                    }
                }
                
                // Categorized Memory Micro-Pills with Discrete Colored Dots
                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Circle().fill(ThemeColors.accentBlue).frame(width: 3, height: 3)
                        Text("App: 21.5 GB")
                            .font(.sfSans(8, weight: .medium))
                            .monospacedDigit()
                            .lineLimit(1)
                            .foregroundColor(ThemeColors.accentBlue)
                    }
                    HStack(spacing: 2) {
                        Circle().fill(ThemeColors.accentPurple).frame(width: 3, height: 3)
                        Text("联动: 4.0 GB")
                            .font(.sfSans(8, weight: .medium))
                            .monospacedDigit()
                            .lineLimit(1)
                            .foregroundColor(ThemeColors.purpleLight)
                    }
                    HStack(spacing: 2) {
                        Circle().fill(ThemeColors.accentOrange).frame(width: 3, height: 3)
                        Text("压缩: 5.1 GB")
                            .font(.sfSans(8))
                            .monospacedDigit()
                            .lineLimit(1)
                            .foregroundColor(ThemeColors.textSecondary)
                    }
                    HStack(spacing: 2) {
                        Circle().fill(ThemeColors.textMuted).frame(width: 3, height: 3)
                        Text("可用: 9.4 GB")
                            .font(.sfSans(8))
                            .monospacedDigit()
                            .lineLimit(1)
                            .foregroundColor(ThemeColors.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6.5)
            .industrialCard(cornerRadius: 10)
            
            // ── 4. Storage SSD Card
            VStack(alignment: .leading, spacing: 4.5) {
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10.5))
                        .foregroundColor(ThemeColors.accentBlue)
                        .frame(width: 13)
                    Text("内置存储 SSD")
                        .font(.oppoSans(11.5, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.snapshot.diskUsage))
                        .font(.sfSans(13, weight: .bold, design: .monospaced))
                        .foregroundColor(ThemeColors.textPrimary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(ThemeColors.matteCardSecondary).frame(height: 3.5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x00A3FF).opacity(0.85), Color(hex: 0x38BDF8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.0, monitor.snapshot.diskUsage / 100.0))), height: 3.5)
                    }
                }
                .frame(height: 3.5)
                
                HStack {
                    Text("Macintosh HD · APFS")
                        .font(.oppoSans(9.5))
                        .foregroundColor(ThemeColors.textMuted)
                    Spacer()
                    Text(String(format: "已用 %.0f GB / 总共 %.0f GB", monitor.snapshot.diskUsedGB, monitor.snapshot.diskTotalGB))
                        .font(.sfSans(9.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(ThemeColors.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .industrialCard(cornerRadius: 10)
            
            // ── 5. Intel Desktop Power & Uptime Card (NO BATTERY MOCK!)
            VStack(alignment: .leading, spacing: 4.5) {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 10.5))
                        .foregroundColor(ThemeColors.textSecondary)
                        .frame(width: 13)
                    Text("系统运行状态 · 台式机")
                        .font(.oppoSans(11.5, weight: .semibold))
                        .foregroundColor(ThemeColors.textPrimary)
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(ThemeColors.accentGreen).frame(width: 3.5, height: 3.5)
                        Text("稳定直供")
                            .font(.oppoSans(9, weight: .medium))
                            .foregroundColor(ThemeColors.accentGreen)
                    }
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1)
                    .background(ThemeColors.matteCardSecondary)
                    .cornerRadius(3)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 1.5) {
                        Text("供电方式")
                            .font(.oppoSans(9))
                            .foregroundColor(ThemeColors.textMuted)
                        Text("交流电源 (AC Power)")
                            .font(.oppoSans(10, weight: .medium))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 1.5) {
                        Text("开机运行时间")
                            .font(.oppoSans(9))
                            .foregroundColor(ThemeColors.textMuted)
                        Text(monitor.snapshot.uptime)
                            .font(.sfSans(10, weight: .semibold, design: .monospaced))
                            .foregroundColor(ThemeColors.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1.5) {
                        Text("系统平均负载")
                            .font(.oppoSans(9))
                            .foregroundColor(ThemeColors.textMuted)
                        Text(monitor.snapshot.loadAvg)
                            .font(.sfSans(10, weight: .semibold, design: .monospaced))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ThemeColors.matteCardSecondary)
    }
}

// MARK: - 2. Dedicated Independent AI Popup View
struct AIPopupView: View {
    @ObservedObject var quotaMgr: QuotaManager
    @Namespace private var aiTabNamespace
    @State private var isCloseHovered: Bool = false
    
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
                        profile: quotaMgr.profile(for: source)
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
        HStack(alignment: .center, spacing: 10) {
            PulseBrandBadge()
            
            VStack(alignment: .leading, spacing: 0) {
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
                
                Spacer(minLength: 0)
                
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
                .offset(y: 3.5)
            }
            .frame(height: 32)
            
            Spacer(minLength: 4)
            
            // ── Dedicated Exit AI Button (Bare SVG glyph, Gray initially, Glowing Red on hover)
            Button(action: onExit) {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isCloseHovered ? Color(hex: 0xEF4444) : Color.white.opacity(0.38))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disableFocusRing()
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isCloseHovered = hovering
                }
            }
            .help("退出 AI 状态栏")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
    
    // Multi-AI Provider Rail: Ultra-Refined Frosted Glass Capsule (Single-Click Status Bar Sync)
    private var aiModelSwitcherView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(ActiveAISource.allCases, id: \.rawValue) { source in
                    let isSelected = (quotaMgr.selectedAITab == source)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            quotaMgr.selectedAITab = source
                            quotaMgr.setStatusAI(source) // 切换直接联动状态栏，无需二次操作！
                        }
                        if source == .codex {
                            quotaMgr.fetchCodexLiveQuota(force: true)
                        } else if source == .antigravity {
                            quotaMgr.fetchAntigravityLiveDaemonQuota(force: true)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: source.iconSystemName)
                                .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? Color(hex: source.accentHex) : Color.white.opacity(0.48))
                            
                            Text(source.title)
                                .font(.sfSans(11, weight: isSelected ? .bold : .regular))
                            
                            if !source.isConfigured {
                                let badgeText = (source == .claude && source.isDetectedOnMachine) ? "待登录" : "待连接"
                                let badgeColor = (source == .claude && source.isDetectedOnMachine) ? Color(hex: 0xF59E0B) : Color.white.opacity(0.50)
                                let badgeBg = (source == .claude && source.isDetectedOnMachine) ? Color(hex: 0xF59E0B).opacity(0.16) : Color.white.opacity(0.08)
                                
                                Text(badgeText)
                                    .font(.pingFangSC(7.5, weight: .medium))
                                    .foregroundColor(badgeColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(badgeBg)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.48))
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
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.18),
                                                Color.white.opacity(0.06)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.50),
                                                        Color.white.opacity(0.12)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.75
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                                    .matchedGeometryEffect(id: "aiActiveCapsule", in: aiTabNamespace)
                            }
                        }
                    )
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.28))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.6
                    )
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
    
    @State private var isEmailVisible: Bool = UserDefaults.standard.bool(forKey: "sysbar_show_real_email")
    
    private var displayEmail: String {
        if isEmailVisible {
            return profile.accountEmail
        } else {
            return maskEmail(profile.accountEmail)
        }
    }
    
    private func maskEmail(_ raw: String) -> String {
        guard raw.contains("@") else {
            return raw
        }
        if let startIdx = raw.firstIndex(of: "("),
           let endIdx = raw.lastIndex(of: ")"),
           startIdx < endIdx {
            let prefix = String(raw[..<startIdx])
            let inner = String(raw[raw.index(after: startIdx)..<endIdx])
            if inner.contains("@") {
                return "\(prefix)(\(maskInnerEmail(inner)))"
            } else {
                return raw
            }
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
            
            // ── Layer 2: Model Quota Gauges OR Provider Setup Slot
            if !profile.categories.isEmpty {
                quotasCard
            } else {
                providerSetupCard
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
                       let img = AIStatusBarView.loadResourceImage(named: "Antigravity") {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    } else if source == .codex,
                              let img = AIStatusBarView.loadResourceImage(named: "Codex") {
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
                
                // Status Pill & Action
                VStack(alignment: .trailing, spacing: 4) {
                    let pillTitle: String = {
                        if source.isConfigured {
                            return profile.isActive ? "Active" : "已无额度"
                        } else if source == .claude && source.isDetectedOnMachine {
                            return "待登录"
                        } else {
                            return "待连接"
                        }
                    }()
                    let pillColor: Color = {
                        if source.isConfigured {
                            return profile.isActive ? Color(hex: 0x86EFAC) : Color(hex: 0xFCA5A5)
                        } else if source == .claude && source.isDetectedOnMachine {
                            return Color(hex: 0xFDE68A)
                        } else {
                            return ThemeColors.textSecondary
                        }
                    }()
                    let pillDotColor: Color = {
                        if source.isConfigured {
                            return profile.isActive ? ThemeColors.accentGreen : Color(hex: 0xEF4444)
                        } else if source == .claude && source.isDetectedOnMachine {
                            return Color(hex: 0xF59E0B)
                        } else {
                            return ThemeColors.textMuted
                        }
                    }()
                    let pillBgColor: Color = {
                        if source.isConfigured {
                            return profile.isActive ? ThemeColors.accentGreen.opacity(0.16) : Color(hex: 0x7F1D1D).opacity(0.4)
                        } else if source == .claude && source.isDetectedOnMachine {
                            return Color(hex: 0xF59E0B).opacity(0.15)
                        } else {
                            return Color.white.opacity(0.06)
                        }
                    }()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(pillDotColor)
                            .frame(width: 4.5, height: 4.5)
                        Text(pillTitle)
                            .font(.sfSans(8.5, weight: .bold))
                            .foregroundColor(pillColor)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(pillBgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pillDotColor.opacity(0.4), lineWidth: 0.6)
                    )
                    .clipShape(Capsule())
                    
                    if source == .antigravity {
                        Button(action: {
                            if let url = URL(string: "https://one.google.com/explore-plan") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Upgrade ↗")
                                .font(.sfSans(8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: 0x2563EB))
                                .cornerRadius(3)
                        }
                        .buttonStyle(.springPress)
                        .disableFocusRing()
                    } else if source == .codex {
                        Button(action: {
                            if let url = URL(string: "https://chatgpt.com/#settings/Subscription") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Manage ↗")
                                .font(.sfSans(8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: 0x059669))
                                .cornerRadius(3)
                        }
                        .buttonStyle(.springPress)
                        .disableFocusRing()
                    }
                }
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
    
    // MARK: - Layer 2 (Alternative): Dynamic Setup / Connection Slot
    private var providerSetupCard: some View {
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
                    if source == .claude && source.isDetectedOnMachine {
                        Text("Claude Code 运行环境已探测")
                            .font(.sfSans(11, weight: .bold))
                            .foregroundColor(ThemeColors.textPrimary)
                        Text("检测到 /usr/local/bin/claude · 待终端授权")
                            .font(.oppoSans(8.5, weight: .medium))
                            .foregroundColor(ThemeColors.textMuted)
                    } else {
                        Text("\(source.title) 本机凭据自动识别")
                            .font(.sfSans(11, weight: .bold))
                            .foregroundColor(ThemeColors.textPrimary)
                        Text("架构就绪 · 本机检测到配置文件即可自动接入")
                            .font(.oppoSans(8.5, weight: .medium))
                            .foregroundColor(ThemeColors.textMuted)
                    }
                }
                
                Spacer()
                
                let statusLabel: String = {
                    if source.isConfigured {
                        return "已就绪"
                    } else if source == .claude && source.isDetectedOnMachine {
                        return "待登录"
                    } else {
                        return "待连接"
                    }
                }()
                let statusColor = (source == .claude && source.isDetectedOnMachine) ? Color(hex: 0xF59E0B) : Color(hex: source.accentHex)
                
                Text(statusLabel)
                    .font(.sfSans(8.5, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(4)
            }
            
            if source == .claude && source.isDetectedOnMachine {
                Text("Pulse 已自动探测到本机安装了 Claude Code CLI 与客户端环境。当前终端授权状态为未登录。点击下方按钮即可唤起终端一键执行登录，或在环境变量中设置 ANTHROPIC_API_KEY。")
                    .font(.oppoSans(9, weight: .regular))
                    .foregroundColor(ThemeColors.textSecondary)
                    .lineSpacing(2.5)
            } else {
                Text("Pulse 支持自动扫描当前用户系统目录下的配置文件与 Token。若已配置环境变量或本地 JSON，即可在状态栏与面板无感切换。")
                    .font(.oppoSans(9, weight: .regular))
                    .foregroundColor(ThemeColors.textSecondary)
                    .lineSpacing(2.5)
            }
            
            HStack(spacing: 8) {
                if source == .claude && source.isDetectedOnMachine {
                    Button(action: {
                        let script = "tell application \"Terminal\" to do script \"claude auth login\""
                        if let appleScript = NSAppleScript(source: script) {
                            var err: NSDictionary?
                            appleScript.executeAndReturnError(&err)
                        }
                        NSWorkspace.shared.launchApplication("Terminal")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                                .font(.system(size: 8.5))
                            Text("终端执行登录 (claude login)")
                                .font(.sfSans(9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: 0xD97706))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.springPress)
                    .disableFocusRing()
                }
                
                Button(action: {
                    let dir = configFileDir(for: source)
                    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(URL(fileURLWithPath: dir))
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 8.5))
                        Text("打开配置目录")
                            .font(.sfSans(9, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ThemeColors.matteCardTertiary)
                    .cornerRadius(5)
                }
                .buttonStyle(.springPress)
                .disableFocusRing()
                
                Button(action: {
                    let urlStr: String
                    switch source {
                    case .claude: urlStr = "https://console.anthropic.com"
                    case .grok: urlStr = "https://x.ai/api"
                    case .deepseek: urlStr = "https://platform.deepseek.com"
                    case .codex: urlStr = "https://platform.openai.com"
                    case .antigravity: urlStr = "https://antigravity.google"
                    }
                    if let url = URL(string: urlStr) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("官方控制台 ↗")
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
        case .claude: return "~/.claude.json"
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
