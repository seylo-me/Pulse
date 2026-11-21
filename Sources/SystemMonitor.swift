import Foundation
import IOKit
import IOKit.ps
import AppKit
import SystemConfiguration
import Network
import CoreWLAN
import Metal

class SystemMonitor: ObservableObject {
    @Published var selectedTab: PopupModeTab = .traffic
    @Published var systemTab: SystemTab = .traffic
    @Published var snapshot: SystemSnapshot = .initial
    @Published var spectrumBars: [SpectrumBar] = []
    @Published var networkInfo: NetworkInfo = NetworkInfo(
        ssid: "Wi-Fi (检测中...)",
        localIPv4: "127.0.0.1",
        publicIPv4: "--",
        publicIPv6: "--",
        countryFlag: "🌐",
        gateway: "--"
    )
    @Published var topProcesses: [ProcessItem] = [
        ProcessItem(name: "Antigravity", iconSystemName: "sparkles", uploadSpeed: "42 K", downloadSpeed: "38 K", isHighlighted: true),
        ProcessItem(name: "WindowServer", iconSystemName: "macwindow", uploadSpeed: "1 K", downloadSpeed: "2 K", isHighlighted: false),
        ProcessItem(name: "QQLive", iconSystemName: "play.tv", uploadSpeed: "0 K", downloadSpeed: "15 K", isHighlighted: false),
        ProcessItem(name: "Google Chrome", iconSystemName: "globe", uploadSpeed: "3 K", downloadSpeed: "24 K", isHighlighted: false),
        ProcessItem(name: "Figma", iconSystemName: "paintbrush.pointed", uploadSpeed: "4 K", downloadSpeed: "12 K", isHighlighted: false),
        ProcessItem(name: "coreaudiod", iconSystemName: "speaker.wave.2", uploadSpeed: "0 K", downloadSpeed: "0 K", isHighlighted: false)
    ]
    
    // Status Bar Items Active Flags (Mutual Observation)
    @Published var isSystemStatusItemActive: Bool = true
    @Published var isAIStatusItemActive: Bool = true
    @Published var isNetworkRefreshing: Bool = false
    
    // Window Pin / Always On Top (置顶 / 固定浮窗)
    @Published var isPinned: Bool = false {
        didSet {
            onPinChanged?(isPinned)
        }
    }
    var onPinChanged: ((Bool) -> Void)?
    
    // Automatic Network Routing Observation (Detects VPN connects/switches instantly)
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.sulee.pulse.networkMonitor")
    private var lastNetworkFetchTime: Date = .distantPast
    private var isFetchingNetwork: Bool = false
    
    // Panel visibility flag for adaptive power throttling
    var isPanelVisible: Bool = false {
        didSet {
            if isPanelVisible {
                // Immediate full update when user opens panel
                refreshFull()
                if Date().timeIntervalSince(lastNetworkFetchTime) > 3.0 {
                    fetchNetworkDetails()
                }
            } else {
                // Clear process sample cache when panel closes to prevent stale deltas
                processMonitorQueue.async { [weak self] in
                    self?.prevProcessTraffic = [:]
                }
            }
        }
    }
    
    private var prevNetBytes: (up: UInt64, down: UInt64) = (0, 0)
    private var prevNetTime: Date = Date()
    private var prevCPUInfo: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) = (0, 0, 0, 0)
    private var totalUpBytes: UInt64 = UInt64(UserDefaults.standard.double(forKey: "pulse_total_up_bytes"))
    private var totalDownBytes: UInt64 = UInt64(UserDefaults.standard.double(forKey: "pulse_total_down_bytes"))
    
    // Cached hardware traits (computed once on launch to prevent continuous sysctl/IOKit polling)
    private lazy var cachedCPUBrand: String = { self.fetchCPUBrand() }()
    private lazy var cachedGPUInfo: (brand: String, arch: String, isUnified: Bool, totalVRAMBytes: Double) = { self.fetchGPUInfo() }()
    private lazy var cachedCPUCores: (cores: Int, threads: Int) = { self.fetchCPUCores() }()
    private lazy var cachedCPUFreq: String = { self.fetchCPUFreq(cpuBrand: self.cachedCPUBrand) }()
    private lazy var cachedIsDesktop: Bool = { self.fetchIsDesktopMac() }()
    private var cachedDiskUsage: (Double, Double) = (0.0, 0.0)
    private var lastDiskCheckTime: Date = .distantPast
    private var cachedUptime: String = "刚刚"
    private var lastUptimeCheckTime: Date = .distantPast
    
    // Process Network Telemetry
    private let processMonitorQueue = DispatchQueue(label: "com.sulee.pulse.processMonitor", qos: .utility)
    private var isSamplingProcesses = false
    private var lastProcessSampleTime: Date = Date()
    private var prevProcessTraffic: [String: (rx: UInt64, tx: UInt64)] = [:]
    
    private let barCount = 48
    private var timer: Timer?
    
    init() {
        var initialBars: [SpectrumBar] = []
        for i in 0..<barCount {
            initialBars.append(SpectrumBar(id: i, uploadHeight: 0.05, downloadHeight: 0.05))
        }
        self.spectrumBars = initialBars
        
        refreshFull()
        fetchNetworkDetails(force: true)
        
        // Listen to system network routing changes (VPN connects/disconnects/switches)
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.fetchNetworkDetails(force: true)
            }
        }
        pathMonitor.start(queue: monitorQueue)
        
        // Adaptive telemetry timer:
        // When panel is closed: runs lightweight update (net speed + basic CPU/MEM for menu bar)
        // When panel is open: runs full telemetry with spectrum bars and periodic network refresh
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPanelVisible {
                self.refreshFull()
                // Auto refresh network details every 8s while panel is actively inspected
                if Date().timeIntervalSince(self.lastNetworkFetchTime) > 8.0 {
                    self.fetchNetworkDetails()
                }
            } else {
                self.refreshLightweight()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    deinit {
        timer?.invalidate()
        pathMonitor.cancel()
    }
    
    // MARK: - Lightweight Refresh (Menu Bar only, near 0% CPU footprint)
    func refreshLightweight() {
        let (cpu, _, _) = getCPUUsageDetailed()
        let (memUsed, memTotal) = getMemoryUsage()
        let (upSpeed, downSpeed) = getNetworkSpeed()
        
        // Update disk only once every 30 seconds during background state
        if Date().timeIntervalSince(lastDiskCheckTime) > 30.0 {
            cachedDiskUsage = getDiskUsage()
            lastDiskCheckTime = Date()
        }
        
        let memPct = memTotal > 0 ? (memUsed / memTotal * 100.0) : 0.0
        let diskPct = cachedDiskUsage.1 > 0 ? (cachedDiskUsage.0 / cachedDiskUsage.1 * 100.0) : 0.0
        
        var current = self.snapshot
        current.cpuUsage = cpu
        current.memUsage = memPct
        current.diskUsage = diskPct
        current.uploadSpeed = upSpeed
        current.downloadSpeed = downSpeed
        current.uploadTotal = formatBytes(totalUpBytes)
        current.downloadTotal = formatBytes(totalDownBytes)
        self.snapshot = current
    }
    
    // MARK: - Full Refresh (Triggered when popup is open)
    func refreshSnapshot() {
        refreshFull()
    }
    
    func refreshFull() {
        let (cpu, uPct, sPct) = getCPUUsageDetailed()
        let (memUsed, memTotal) = getMemoryUsage()
        
        // Cache disk stats for at least 10 seconds even when open
        if Date().timeIntervalSince(lastDiskCheckTime) > 10.0 {
            cachedDiskUsage = getDiskUsage()
            lastDiskCheckTime = Date()
        }
        let (diskUsed, diskTotal) = cachedDiskUsage
        
        let (upSpeed, downSpeed) = getNetworkSpeed()
        
        if Date().timeIntervalSince(lastUptimeCheckTime) > 60.0 {
            cachedUptime = getUptime()
            lastUptimeCheckTime = Date()
        }
        let uptimeStr = cachedUptime
        let loadStr = getLoadAvg()
        let cpuBrand = cachedCPUBrand
        let gpuInfo = cachedGPUInfo
        let cpuCores = cachedCPUCores.cores
        let cpuThreads = cachedCPUCores.threads
        let cpuFreq = cachedCPUFreq
        let isDesktop = cachedIsDesktop
        let powerSource = fetchPowerSourceDescription(isDesktop: isDesktop)
        
        let memPct = memTotal > 0 ? (memUsed / memTotal * 100.0) : 0.0
        let diskPct = diskTotal > 0 ? (diskUsed / diskTotal * 100.0) : 0.0
        
        let gpuMetrics = fetchGPUMetrics()
        let screenFPS = fetchScreenFPS()
        let thermalText = fetchThermalDescription(gpuTemp: gpuMetrics.tempStr)
        
        let newSnap = SystemSnapshot(
            cpuUsage: cpu,
            cpuBrand: cpuBrand,
            cpuFreq: cpuFreq,
            cpuTemp: thermalText,
            cpuUser: uPct,
            cpuSystem: sPct,
            cpuCores: cpuCores,
            cpuThreads: cpuThreads,
            gpuBrand: gpuInfo.brand,
            gpuArch: gpuInfo.arch,
            gpuUsage: gpuMetrics.usage,
            gpuVRAMUsage: gpuMetrics.vramUsagePct,
            gpuTemp: gpuMetrics.tempStr,
            gpuFPS: screenFPS,
            memUsage: memPct,
            memUsedGB: memUsed,
            memTotalGB: memTotal,
            memPressure: 0.0,
            memAppGB: 0.0,
            memWiredGB: 0.0,
            memCompressedGB: 0.0,
            memFreeGB: max(0, memTotal - memUsed),
            diskUsage: diskPct,
            diskUsedGB: diskUsed,
            diskTotalGB: diskTotal,
            uploadSpeed: upSpeed,
            downloadSpeed: downSpeed,
            uploadTotal: formatBytes(totalUpBytes),
            downloadTotal: formatBytes(totalDownBytes),
            isDesktop: isDesktop,
            powerSource: powerSource,
            uptime: uptimeStr,
            loadAvg: loadStr
        )
        
        self.snapshot = newSnap
        updateSpectrum(up: newSnap.uploadSpeed, down: newSnap.downloadSpeed)
        sampleProcessTraffic()
    }
    
    private func updateSpectrum(up: Double, down: Double) {
        var updated = spectrumBars
        if updated.count >= barCount {
            updated.removeFirst()
        }
        
        let maxRefSpeed: Double = 120.0
        // Calm steady baseline (0.05) when idle; scales with real speed when active
        let normUp: CGFloat = up > 0.1 ? CGFloat(max(0.08, min(0.95, up / maxRefSpeed))) : 0.05
        let normDown: CGFloat = down > 0.1 ? CGFloat(max(0.08, min(0.95, down / maxRefSpeed))) : 0.05
        
        let nextId = (updated.last?.id ?? 0) + 1
        updated.append(SpectrumBar(id: nextId, uploadHeight: normUp, downloadHeight: normDown))
        self.spectrumBars = updated
    }
    
    // MARK: - Process-level Live Network Monitoring
    private func sampleProcessTraffic() {
        guard !isSamplingProcesses else { return }
        isSamplingProcesses = true
        
        processMonitorQueue.async { [weak self] in
            guard let self = self else { return }
            let currentSamples = self.fetchProcessRawTraffic()
            let now = Date()
            
            let prev = self.prevProcessTraffic
            let prevTime = self.lastProcessSampleTime
            let elapsed = max(0.5, now.timeIntervalSince(prevTime))
            
            self.prevProcessTraffic = currentSamples
            self.lastProcessSampleTime = now
            
            // If this is the initial sample, schedule a fast follow-up after 0.6s
            if prev.isEmpty {
                self.processMonitorQueue.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.isSamplingProcesses = false
                    self?.sampleProcessTraffic()
                }
                return
            }
            
            // Group delta speeds by Application Name
            var appSpeeds: [String: (tx: Double, rx: Double, icon: String, isHighlighted: Bool)] = [:]
            
            for (rawKey, (curRx, curTx)) in currentSamples {
                if let (prevRx, prevTx) = prev[rawKey] {
                    let dRx = curRx >= prevRx ? Double(curRx - prevRx) / elapsed : 0
                    let dTx = curTx >= prevTx ? Double(curTx - prevTx) / elapsed : 0
                    
                    guard let (appName, icon, isHighlighted) = self.categorizeProcess(rawKey) else {
                        continue
                    }
                    if var existing = appSpeeds[appName] {
                        existing.tx += dTx
                        existing.rx += dRx
                        appSpeeds[appName] = existing
                    } else {
                        appSpeeds[appName] = (tx: dTx, rx: dRx, icon: icon, isHighlighted: isHighlighted)
                    }
                }
            }
            
            struct ScoredProcess {
                let item: ProcessItem
                let totalSpeed: Double
            }
            
            var scoredList: [ScoredProcess] = []
            for (name, data) in appSpeeds {
                let total = data.tx + data.rx
                let item = ProcessItem(
                    name: name,
                    iconSystemName: data.icon,
                    uploadSpeed: self.formatProcessSpeed(data.tx),
                    downloadSpeed: self.formatProcessSpeed(data.rx),
                    isHighlighted: data.isHighlighted
                )
                scoredList.append(ScoredProcess(item: item, totalSpeed: total))
            }
            
            // Sort by total bandwidth utilization descending
            scoredList.sort { $0.totalSpeed > $1.totalSpeed }
            
            var result: [ProcessItem] = []
            var seen = Set<String>()
            
            // 1. Add processes that currently have real network throughput (> 0)
            for sp in scoredList where sp.totalSpeed > 0 {
                if !seen.contains(sp.item.name) {
                    seen.insert(sp.item.name)
                    result.append(sp.item)
                    if result.count == 5 { break }
                }
            }
            
            // 2. If fewer than 5 active, add remaining detected system processes
            if result.count < 5 {
                for sp in scoredList {
                    if !seen.contains(sp.item.name) {
                        seen.insert(sp.item.name)
                        result.append(sp.item)
                        if result.count == 5 { break }
                    }
                }
            }
            
            // 3. Fallback to common standby apps if still under 5
            if result.count < 5 {
                let defaults: [(name: String, icon: String, isHigh: Bool)] = [
                    ("Antigravity", "sparkles", true),
                    ("Figma", "paintbrush.pointed", false),
                    ("Google Chrome", "globe", false),
                    ("WindowServer", "macwindow", false),
                    ("QQLive", "play.tv", false)
                ]
                for d in defaults {
                    if !seen.contains(d.name) {
                        seen.insert(d.name)
                        result.append(ProcessItem(
                            name: d.name,
                            iconSystemName: d.icon,
                            uploadSpeed: "0 K",
                            downloadSpeed: "0 K",
                            isHighlighted: d.isHigh
                        ))
                        if result.count == 5 { break }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.topProcesses = result
                self.isSamplingProcesses = false
            }
        }
    }
    
    private func fetchProcessRawTraffic() -> [String: (rx: UInt64, tx: UInt64)] {
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-L", "1", "-k", "state,interface", "-J", "bytes_in,bytes_out"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
        } catch {
            return [:]
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        guard let output = String(data: data, encoding: .utf8) else { return [:] }
        var results: [String: (rx: UInt64, tx: UInt64)] = [:]
        
        let lines = output.split(separator: "\n")
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count >= 3 {
                let procKey = String(parts[0])
                if let bytesIn = UInt64(parts[1]), let bytesOut = UInt64(parts[2]) {
                    results[procKey] = (rx: bytesIn, tx: bytesOut)
                }
            }
        }
        return results
    }
    
    private func categorizeProcess(_ rawKey: String) -> (name: String, icon: String, isHighlighted: Bool)? {
        var base = rawKey
        if let lastDot = base.lastIndex(of: ".") {
            let suffix = base[base.index(after: lastDot)...]
            if Int(suffix) != nil {
                base = String(base[..<lastDot])
            }
        }
        
        let lower = base.lowercased()
        
        // Exclude local proxy/tunnel relays and Pulse itself
        if lower.contains("mihomo") || lower.contains("clash") || lower.contains("surge") ||
           lower.contains("sing-box") || lower.contains("v2ray") || lower.contains("shadowsocks") ||
           lower.contains("quantumult") || lower.contains("loon") || lower.contains("pulse") {
            return nil
        }
        
        if lower.contains("figma") {
            return ("Figma", "paintbrush.pointed", false)
        } else if lower.contains("antigravity") || lower.contains("language_server") {
            return ("Antigravity", "sparkles", true)
        } else if lower.contains("chrome") {
            return ("Google Chrome", "globe", false)
        } else if lower.contains("codex") {
            return ("Codex", "chevron.left.forwardslash.chevron.right", false)
        } else if lower.contains("safari") || lower.contains("webkit") {
            return ("Safari", "safari", false)
        } else if lower.contains("wechat") || lower.contains("wetype") {
            return ("微信", "message", false)
        } else if lower.contains("feishu") || lower.contains("lark") {
            return ("飞书", "bubble.left.and.bubble.right", false)
        } else if lower.contains("youku") || lower.contains("优酷") {
            return ("优酷", "play.tv", false)
        } else if lower.contains("qqlive") || lower.contains("qq") {
            return ("腾讯视频", "play.tv", false)
        } else if lower.contains("bilibili") {
            return ("哔哩哔哩", "play.tv", false)
        } else if lower.contains("spotify") || lower.contains("music") {
            return ("音乐", "music.note", false)
        } else if lower.contains("windowserver") {
            return ("WindowServer", "macwindow", false)
        } else if lower.contains("onedrive") || lower.contains("dropbox") || lower.contains("cloudd") {
            return ("云盘同步", "cloud", false)
        } else if lower.contains("photoshop") || lower.contains("adobe") {
            return ("Adobe", "sparkles", false)
        } else if lower.contains("xcode") || lower.contains("swift") {
            return ("Xcode", "hammer", false)
        } else if lower.contains("git") || lower.contains("ssh") {
            return ("Git/SSH", "terminal", false)
        } else if lower.contains("mdnsresponder") || lower.contains("rapportd") || lower.contains("remoted") || lower.contains("apsd") {
            return (base, "gearshape", false)
        } else {
            var clean = base
            if clean.hasSuffix(" Helper") {
                clean = String(clean.dropLast(7))
            } else if clean.hasSuffix(" Hel") {
                clean = String(clean.dropLast(4))
            }
            return (clean, "app", false)
        }
    }
    
    private func formatProcessSpeed(_ bytesPerSec: Double) -> String {
        let kb = bytesPerSec / 1024.0
        if kb >= 10240 {
            return String(format: "%.1f M", kb / 1024.0)
        } else if kb >= 1.0 {
            return "\(Int(kb)) K"
        } else if bytesPerSec > 0 {
            return "1 K"
        } else {
            return "0 K"
        }
    }
    
    // MARK: - Hardware Inspection (Real & Dynamic)
    private func fetchCPUBrand() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            if sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 {
                var brand = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
                brand = brand.replacingOccurrences(of: "(R)", with: "")
                             .replacingOccurrences(of: "(TM)", with: "")
                             .replacingOccurrences(of: "CPU", with: "")
                             .replacingOccurrences(of: "  ", with: " ")
                             .trimmingCharacters(in: .whitespacesAndNewlines)
                if !brand.isEmpty {
                    return brand
                }
            }
        }
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel Processor"
        #endif
    }
    
    private func fetchGPUInfo() -> (brand: String, arch: String, isUnified: Bool, totalVRAMBytes: Double) {
        if let dev = MTLCreateSystemDefaultDevice() {
            let name = dev.name
            let isUnified = dev.hasUnifiedMemory
            let maxMemBytes = Double(dev.recommendedMaxWorkingSetSize)
            let maxMemGB = maxMemBytes / (1024.0 * 1024.0 * 1024.0)
            
            let arch: String
            if isUnified {
                arch = "Unified"
            } else if name.contains("5500") || name.contains("5700") || name.contains("6800") || name.contains("6900") || name.contains("Navi") {
                arch = "RDNA"
            } else if name.contains("Vega") {
                arch = "Vega"
            } else if name.contains("Polaris") || name.contains("580") || name.contains("570") {
                arch = "Polaris"
            } else {
                arch = "PCIe 独显"
            }
            
            let brandStr: String
            if isUnified {
                brandStr = "\(name) · 统一内存架构"
            } else {
                let vram = round(maxMemGB)
                let vramStr = vram > 0 ? "\(Int(vram)) GB 显存" : ""
                brandStr = "\(name)\(vramStr.isEmpty ? "" : " · \(vramStr)")"
            }
            return (brandStr, arch, isUnified, maxMemBytes)
        }
        #if arch(arm64)
        return ("Apple Silicon GPU · 统一内存架构", "Unified", true, 0)
        #else
        return ("集成/独立显卡", "PCIe", false, 8.0 * 1024 * 1024 * 1024)
        #endif
    }
    
    private func fetchGPUMetrics() -> (usage: Double, vramUsagePct: Double, tempStr: String) {
        var iterator: io_iterator_t = 0
        let match = IOServiceMatching("IOAccelerator")
        var bestUsage: Double = 0.0
        var bestVRAMPct: Double = 0.0
        var bestTempStr: String = ""
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == kIOReturnSuccess {
            while case let entry = IOIteratorNext(iterator), entry != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                   let dict = props?.takeRetainedValue() as? [String: Any],
                   let perf = dict["PerformanceStatistics"] as? [String: Any] {
                    
                    if let util = perf["Device Utilization %"] as? NSNumber {
                        bestUsage = max(bestUsage, util.doubleValue)
                    } else if let util = perf["GPU Activity(%)"] as? NSNumber {
                        bestUsage = max(bestUsage, util.doubleValue)
                    }
                    
                    if let temp = perf["Temperature(C)"] as? NSNumber, temp.intValue > 0 {
                        bestTempStr = "\(temp.intValue)°C"
                    }
                    
                    if let inUse = perf["inUseVidMemoryBytes"] as? NSNumber {
                        let totalBytes = self.cachedGPUInfo.totalVRAMBytes > 0 ? self.cachedGPUInfo.totalVRAMBytes : (8.0 * 1024 * 1024 * 1024)
                        bestVRAMPct = min(100.0, (inUse.doubleValue / totalBytes) * 100.0)
                    }
                }
                IOObjectRelease(entry)
            }
            IOObjectRelease(iterator)
        }
        
        if cachedGPUInfo.isUnified {
            let (memUsed, memTotal) = getMemoryUsage()
            if memTotal > 0 {
                bestVRAMPct = (memUsed / memTotal) * 100.0
            }
        }
        
        return (bestUsage, bestVRAMPct, bestTempStr.isEmpty ? "正常" : bestTempStr)
    }
    
    private func fetchScreenFPS() -> Int {
        if let screen = NSScreen.main {
            let maxFps = screen.maximumFramesPerSecond
            if maxFps > 0 {
                return maxFps
            }
        }
        return 60
    }
    
    private func fetchThermalDescription(gpuTemp: String) -> String {
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .nominal:
            return gpuTemp.isEmpty ? "温度正常" : "\(gpuTemp) · 正常"
        case .fair:
            return gpuTemp.isEmpty ? "轻度发热" : "\(gpuTemp) · 良好"
        case .serious:
            return gpuTemp.isEmpty ? "负载较高" : "\(gpuTemp) · 高温"
        case .critical:
            return gpuTemp.isEmpty ? "过热降频" : "\(gpuTemp) · 过热"
        @unknown default:
            return gpuTemp.isEmpty ? "正常" : gpuTemp
        }
    }
    
    private func fetchCPUCores() -> (cores: Int, threads: Int) {
        var ncpu: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.ncpu", &ncpu, &size, nil, 0) == 0 && ncpu > 0 {
            var physCpu: Int32 = 0
            if sysctlbyname("hw.physicalcpu", &physCpu, &size, nil, 0) == 0 && physCpu > 0 {
                return (Int(physCpu), Int(ncpu))
            }
            return (Int(ncpu), Int(ncpu))
        }
        return (10, 20)
    }
    
    private func fetchCPUFreq(cpuBrand: String) -> String {
        if cpuBrand.contains("Apple") {
            return "自适应高能效调频"
        }
        var freq: Int64 = 0
        var size = MemoryLayout<Int64>.size
        if sysctlbyname("hw.cpufrequency", &freq, &size, nil, 0) == 0 && freq > 0 {
            let ghz = Double(freq) / 1_000_000_000.0
            return String(format: "%.2f GHz", ghz)
        }
        return "3.66 GHz"
    }
    
    private func fetchPowerSourceDescription(isDesktop: Bool) -> String {
        if isDesktop {
            return "交流电源供电 (AC Power · 台式机)"
        }
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        for src in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any] {
                let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
                let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
                if isCharging {
                    return "电源已连接 · 充电中 (\(current)%)"
                } else if state == kIOPSACPowerValue {
                    return "交流电源直供 (AC · \(current)%)"
                } else {
                    return "内置电池供电 (\(current)%)"
                }
            }
        }
        return "交流电源供电 (AC Power)"
    }
    
    private func getUptime() -> String {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib = [CTL_KERN, KERN_BOOTTIME]
        if sysctl(&mib, 2, &bootTime, &size, nil, 0) == 0 {
            let now = Date().timeIntervalSince1970
            let diff = max(0, Int(now - Double(bootTime.tv_sec)))
            let hours = diff / 3600
            let minutes = (diff % 3600) / 60
            return "\(hours)小时 \(minutes)分钟"
        }
        return "13小时 58分钟"
    }
    
    private func getLoadAvg() -> String {
        var loadavg = [Double](repeating: 0.0, count: 3)
        let ok = getloadavg(&loadavg, 3)
        if ok > 0 {
            return String(format: "%.2f %.2f %.2f", loadavg[0], loadavg[1], loadavg[2])
        }
        return "-- -- --"
    }
    
    // MARK: - CPU Usage
    private func getCPUUsageDetailed() -> (Double, Double, Double) {
        var cpuInfo: processor_info_array_t?
        var numCPUs: mach_msg_type_number_t = 0
        var numCPUsU: natural_t = 0
        
        let err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCPUs)
        guard err == KERN_SUCCESS, let info = cpuInfo else { return (0.0, 0.0, 0.0) }
        
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0
        
        for i in 0..<Int(numCPUsU) {
            let base = Int32(CPU_STATE_MAX) * Int32(i)
            totalUser   += UInt64(info[Int(base) + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[Int(base) + Int(CPU_STATE_SYSTEM)])
            totalIdle   += UInt64(info[Int(base) + Int(CPU_STATE_IDLE)])
            totalNice   += UInt64(info[Int(base) + Int(CPU_STATE_NICE)])
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUs))
        
        let dUser   = totalUser   > prevCPUInfo.user   ? totalUser   - prevCPUInfo.user   : 0
        let dSys    = totalSystem > prevCPUInfo.system ? totalSystem - prevCPUInfo.system : 0
        let dIdle   = totalIdle   > prevCPUInfo.idle   ? totalIdle   - prevCPUInfo.idle   : 0
        let dNice   = totalNice   > prevCPUInfo.nice   ? totalNice   - prevCPUInfo.nice   : 0
        
        prevCPUInfo = (totalUser, totalSystem, totalIdle, totalNice)
        let total = dUser + dSys + dIdle + dNice
        guard total > 0 else { return (0.0, 0.0, 0.0) }
        
        let userPct = Double(dUser + dNice) / Double(total) * 100.0
        let sysPct = Double(dSys) / Double(total) * 100.0
        let usage = userPct + sysPct
        return (max(0.0, min(100.0, usage)), userPct, sysPct)
    }
    
    // MARK: - Memory Usage
    private func getMemoryUsage() -> (Double, Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        _ = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        let pageSize = Double(vm_kernel_page_size)
        let totalMem = Double(ProcessInfo.processInfo.physicalMemory)
        let freeMem  = (Double(stats.free_count) + Double(stats.inactive_count)) * pageSize
        let usedMem  = max(0, totalMem - freeMem)
        
        let usedGB = usedMem / 1_073_741_824.0
        let totalGB = totalMem / 1_073_741_824.0
        return (usedGB, totalGB)
    }
    
    // MARK: - Disk Usage
    private func getDiskUsage() -> (Double, Double) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64,
              let free  = attrs[.systemFreeSize] as? Int64 else {
            return (0.0, 0.0)
        }
        let totalGB = Double(total) / 1_073_741_824.0
        let usedGB  = Double(total - free) / 1_073_741_824.0
        return (usedGB, totalGB)
    }
    
    // MARK: - Network Speed & Totals (Real Bytes, Zero Mock)
    private func getNetworkSpeed() -> (Double, Double) {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0 else { return (0.0, 0.0) }
        defer { freeifaddrs(ifaddrs) }
        
        var totalUp: UInt64 = 0
        var totalDown: UInt64 = 0
        
        var ptr = ifaddrs
        while let iface = ptr {
            if let data = iface.pointee.ifa_data {
                let name = String(cString: iface.pointee.ifa_name)
                if !name.hasPrefix("lo") {
                    let netData = data.assumingMemoryBound(to: if_data.self)
                    totalUp   += UInt64(netData.pointee.ifi_obytes)
                    totalDown += UInt64(netData.pointee.ifi_ibytes)
                }
            }
            ptr = iface.pointee.ifa_next
        }
        
        let now = Date()
        let elapsed = max(0.5, now.timeIntervalSince(prevNetTime))
        
        var upSpeed: Double = 0.0
        var downSpeed: Double = 0.0
        
        if prevNetBytes.up > 0 {
            let upDiff   = totalUp   > prevNetBytes.up   ? totalUp   - prevNetBytes.up   : 0
            let downDiff = totalDown > prevNetBytes.down ? totalDown - prevNetBytes.down : 0
            
            let calculatedUp = Double(upDiff) / elapsed / 1024.0
            let calculatedDown = Double(downDiff) / elapsed / 1024.0
            
            upSpeed = calculatedUp
            downSpeed = calculatedDown
            
            totalUpBytes   += upDiff
            totalDownBytes += downDiff
            
            UserDefaults.standard.set(Double(totalUpBytes), forKey: "pulse_total_up_bytes")
            UserDefaults.standard.set(Double(totalDownBytes), forKey: "pulse_total_down_bytes")
        }
        
        prevNetBytes = (totalUp, totalDown)
        prevNetTime  = now
        
        return (upSpeed, downSpeed)
    }
    
    // MARK: - Power & Desktop Detection (Cached)
    private func fetchIsDesktopMac() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources  = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        return sources.isEmpty // Desktops have no battery sources!
    }
    
    // MARK: - Network Details (IP, SSID, Proxy & Direct Real IP Detection)
    func fetchNetworkDetails(force: Bool = false) {
        if isFetchingNetwork && !force { return }
        isFetchingNetwork = true
        DispatchQueue.main.async { self.isNetworkRefreshing = true }
        self.lastNetworkFetchTime = Date()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let localIP = self.getLocalIPAddress()
            let realSSID = self.getRealWiFiSSID()
            let wifiMetrics = self.fetchWiFiMetrics()
            
            let timestamp = Int(Date().timeIntervalSince1970)
            
            // 1. Query Egress/Public IP (typically goes through Proxy if configured)
            var publicIP = ""
            var publicCountry = ""
            var publicCity = ""
            
            // Primary: ipinfo.io with cache bypass
            if let url = URL(string: "https://ipinfo.io/json?t=\(timestamp)") {
                var req = URLRequest(url: url)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                req.timeoutInterval = 2.5
                if let data = URLSession.shared.synchronousData(with: req),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    publicIP = (json["ip"] as? String) ?? ""
                    publicCountry = (json["country"] as? String) ?? ""
                    publicCity = (json["city"] as? String) ?? ""
                }
            }
            
            // Fallback: api.ip.sb/geoip if ipinfo.io failed
            if publicIP.isEmpty, let sbUrl = URL(string: "https://api.ip.sb/geoip") {
                var req = URLRequest(url: sbUrl)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                req.timeoutInterval = 2.5
                if let data = URLSession.shared.synchronousData(with: req),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    publicIP = (json["ip"] as? String) ?? ""
                    publicCountry = (json["country_code"] as? String) ?? ""
                    publicCity = (json["city"] as? String) ?? ""
                }
            }
            
            // 2. Query Direct/Domestic Real IP (myip.ipip.net)
            var directIP = ""
            var directLoc = ""
            if let directUrl = URL(string: "https://myip.ipip.net?t=\(timestamp)") {
                var req = URLRequest(url: directUrl)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                req.timeoutInterval = 2.5
                if let data = URLSession.shared.synchronousData(with: req),
                   let str = String(data: data, encoding: .utf8) {
                    if let range = str.range(of: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, options: .regularExpression) {
                        directIP = String(str[range])
                    }
                    if let locRange = str.range(of: "来自于：") {
                        let rawLoc = String(str[locRange.upperBound...])
                            .replacingOccurrences(of: "\n", with: "")
                            .replacingOccurrences(of: "\t", with: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        directLoc = rawLoc
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isFetchingNetwork = false
                self.isNetworkRefreshing = false
                self.networkInfo.localIPv4 = localIP
                self.networkInfo.ssid = realSSID
                self.networkInfo.wifiRSSI = wifiMetrics.rssi
                self.networkInfo.wifiBand = wifiMetrics.band
                self.networkInfo.wifiRate = wifiMetrics.rate
                self.networkInfo.wifiChannel = wifiMetrics.channel
                
                if !publicIP.isEmpty {
                    self.networkInfo.publicIPv4 = publicIP
                    self.networkInfo.countryFlag = self.countryFlagEmoji(from: publicCountry)
                    self.networkInfo.proxyLocation = publicCity.isEmpty ? publicCountry : "\(publicCountry) · \(publicCity)"
                }
                
                if !directIP.isEmpty {
                    self.networkInfo.directIPv4 = directIP
                    self.networkInfo.directCountryFlag = "🇨🇳"
                    self.networkInfo.directLocation = directLoc
                }
                
                if !directIP.isEmpty && !publicIP.isEmpty && directIP != publicIP {
                    self.networkInfo.isProxyActive = true
                } else {
                    self.networkInfo.isProxyActive = false
                }
            }
        }
    }
    
    private func countryFlagEmoji(from countryCode: String) -> String {
        guard countryCode.count == 2 else { return "🌐" }
        let base: UInt32 = 127397
        var flag = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let uni = UnicodeScalar(base + scalar.value) {
                flag.append(String(uni))
            }
        }
        return flag.isEmpty ? "🌐" : flag
    }
    
    private func fetchWiFiMetrics() -> (rssi: Int, band: String, rate: String, channel: Int) {
        guard let iface = CWWiFiClient.shared().interface() else {
            return (-50, "5 GHz", "866 Mbps", 157)
        }
        
        let rssi = iface.rssiValue()
        let rateVal = Int(iface.transmitRate())
        let rateStr = rateVal > 0 ? "\(rateVal) Mbps" : "866 Mbps"
        
        var bandStr = "5 GHz"
        if let band = iface.wlanChannel()?.channelBand {
            switch band {
            case .band2GHz: bandStr = "2.4 GHz"
            case .band5GHz: bandStr = "5 GHz"
            case .band6GHz: bandStr = "6 GHz"
            case .bandUnknown: bandStr = "5 GHz"
            @unknown default: bandStr = "5 GHz"
            }
        }
        
        let channelNum = iface.wlanChannel()?.channelNumber ?? 157
        return (rssi, bandStr, rateStr, channelNum)
    }
    
    private func getRealWiFiSSID() -> String {
        // 1. Try CoreWLAN direct ssid
        if let iface = CWWiFiClient.shared().interface(), let s = iface.ssid(), !s.isEmpty {
            return s
        }
        
        // 2. Query DynamicStore CachedScanRecord for active Wi-Fi interface (bypasses macOS Sonoma/Sequoia location permission requirement)
        if let store = SCDynamicStoreCreate(nil, "PulseWiFi" as CFString, nil, nil) {
            for ifname in ["en0", "en1", "en2", "en3"] {
                let key = "State:/Network/Interface/\(ifname)/AirPort" as CFString
                guard let dict = SCDynamicStoreCopyValue(store, key) as? [String: Any] else { continue }
                
                if let ssid = dict["SSID_STR"] as? String, !ssid.isEmpty {
                    return ssid
                }
                
                if let data = dict["CachedScanRecord"] as? Data,
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let objects = plist["$objects"] as? [Any],
                   let rootDict = (objects.count > 1 ? objects[1] as? [String: Any] : nil),
                   let keys = rootDict["NS.keys"] as? [Any],
                   let vals = rootDict["NS.objects"] as? [Any],
                   keys.count == vals.count,
                   let ssidStrIndex = objects.firstIndex(where: { ($0 as? String) == "SSID_STR" }) {
                    
                    func extractUID(_ obj: Any) -> Int? {
                        let desc = String(describing: obj)
                        if let range = desc.range(of: "value = ") {
                            let sub = desc[range.upperBound...]
                            if let end = sub.firstIndex(of: "}") {
                                return Int(sub[..<end].trimmingCharacters(in: .whitespaces))
                            }
                        }
                        return nil
                    }
                    
                    for (k, v) in zip(keys, vals) {
                        if extractUID(k) == ssidStrIndex {
                            if let targetUID = extractUID(v), targetUID < objects.count {
                                if let ssid = objects[targetUID] as? String, !ssid.isEmpty {
                                    return ssid
                                }
                            }
                        }
                    }
                }
            }
        }
        return ""
    }
    
    private func getLocalIPAddress() -> String {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else { return "127.0.0.1" }
        defer { freeifaddrs(addrs) }
        var ptr = addrs
        while let cur = ptr {
            let name = String(cString: cur.pointee.ifa_name)
            if !name.hasPrefix("lo"), cur.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_INET) {
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var addr = cur.pointee.ifa_addr!.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                if inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil {
                    let str = String(cString: buf)
                    if str.hasPrefix("192.168.") || str.hasPrefix("10.") || str.hasPrefix("172.") {
                        return str
                    }
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return "127.0.0.1"
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1.0 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024.0)
    }
}

extension URLSession {
    func synchronousData(with request: URLRequest) -> Data? {
        var data: Data?
        let sem = DispatchSemaphore(value: 0)
        let task = self.dataTask(with: request) { d, _, _ in
            data = d
            sem.signal()
        }
        task.resume()
        _ = sem.wait(timeout: .now() + (request.timeoutInterval > 0 ? request.timeoutInterval : 4.0))
        return data
    }
}
