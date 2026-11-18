import Foundation
import SwiftUI

// MARK: - Dedicated System Panel Tabs (Traffic & Hardware only)
enum SystemTab: Int, CaseIterable {
    case traffic = 0
    case hardware = 1
    
    var title: String {
        switch self {
        case .traffic: return "流量监控"
        case .hardware: return "硬件总览"
        }
    }
    
    var icon: String {
        switch self {
        case .traffic: return "waveform.path.ecg"
        case .hardware: return "cpu"
        }
    }
}

// MARK: - Independent AI Selection (Real Live Monitored AI Providers)
enum ActiveAISource: String, CaseIterable, Codable {
    case antigravity = "antigravity"
    case codex = "codex"
    
    var title: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .codex: return "Codex"
        }
    }
    
    var providerName: String {
        switch self {
        case .antigravity: return "Google AI"
        case .codex: return "OpenAI"
        }
    }
    
    var iconSystemName: String {
        switch self {
        case .antigravity: return "sparkles"
        case .codex: return "bolt.fill"
        }
    }
    
    var accentHex: UInt32 {
        switch self {
        case .antigravity: return 0xA44BFD // Vibrant Purple
        case .codex: return 0x38BDF8       // Codex Sky Blue
        }
    }
    
    var isConfigured: Bool {
        return true
    }
}

// MARK: - Selected Mode Tab (Backward Compatibility)
enum PopupModeTab: Int, CaseIterable {
    case traffic = 0
    case hardware = 1
    case antigravity = 2
    case codex = 3
    
    var title: String {
        switch self {
        case .traffic: return "流量监控"
        case .hardware: return "硬件总览"
        case .antigravity: return "反重力"
        case .codex: return "Codex"
        }
    }
    
    var icon: String {
        switch self {
        case .traffic: return "waveform.path.ecg"
        case .hardware: return "cpu"
        case .antigravity: return "sparkles"
        case .codex: return "bolt.fill"
        }
    }
}

// MARK: - System Snapshot (Intel iMac 2020 Real Hardware Specs)
struct SystemSnapshot {
    // CPU
    var cpuUsage: Double       // 0 - 100
    var cpuBrand: String       // e.g. "10-Core Intel Core i9 @ 3.60 GHz"
    var cpuFreq: String        // e.g. "3.66 GHz"
    var cpuTemp: String        // e.g. "67°C"
    var cpuUser: Double        // e.g. 7%
    var cpuSystem: Double      // e.g. 2%
    var cpuCores: Int          // 10
    var cpuThreads: Int        // 20
    
    // GPU (AMD Radeon Pro 5500 XT)
    var gpuBrand: String       // "AMD Radeon Pro 5500 XT"
    var gpuUsage: Double       // e.g. 6%
    var gpuVRAMUsage: Double   // e.g. 96%
    var gpuTemp: String        // e.g. "69°C"
    var gpuFPS: Int            // e.g. 60
    
    // Memory (40 GB DDR4)
    var memUsage: Double       // e.g. 77%
    var memUsedGB: Double      // e.g. 30.6 GB
    var memTotalGB: Double     // 40.0 GB
    var memPressure: Double    // e.g. 23%
    var memAppGB: Double       // 21.5 GB
    var memWiredGB: Double     // 4.0 GB
    var memCompressedGB: Double // 5.1 GB
    var memFreeGB: Double      // 9.4 GB
    
    // Disk (1863 GB)
    var diskUsage: Double      // e.g. 84%
    var diskUsedGB: Double     // 1562.0 GB
    var diskTotalGB: Double    // 1863.0 GB
    
    // Network Speed
    var uploadSpeed: Double    // KB/s
    var downloadSpeed: Double  // KB/s
    var uploadTotal: String
    var downloadTotal: String
    
    // Power & System State (Intel Desktop - AC Power, No Battery!)
    var isDesktop: Bool        // true
    var powerSource: String    // "交流电源 (AC Power)"
    var uptime: String         // e.g. "14小时 22分钟"
    var loadAvg: String        // e.g. "2.30 3.05 3.41"
    
    static let initial = SystemSnapshot(
        cpuUsage: 2.1,
        cpuBrand: "10-Core Intel Core i9-10910 @ 3.60 GHz",
        cpuFreq: "3.66 GHz",
        cpuTemp: "67°C",
        cpuUser: 1.5,
        cpuSystem: 0.6,
        cpuCores: 10,
        cpuThreads: 20,
        gpuBrand: "AMD Radeon Pro 5500 XT",
        gpuUsage: 8.0,
        gpuVRAMUsage: 96.0,
        gpuTemp: "69°C",
        gpuFPS: 60,
        memUsage: 64.0,
        memUsedGB: 25.7,
        memTotalGB: 40.0,
        memPressure: 23.0,
        memAppGB: 21.5,
        memWiredGB: 4.0,
        memCompressedGB: 5.1,
        memFreeGB: 9.4,
        diskUsage: 84.0,
        diskUsedGB: 1563.0,
        diskTotalGB: 1863.0,
        uploadSpeed: 4.0,
        downloadSpeed: 10.0,
        uploadTotal: "265 MB",
        downloadTotal: "303 MB",
        isDesktop: true,
        powerSource: "交流电源 (AC Power · 稳定直供)",
        uptime: "14小时 22分钟",
        loadAvg: "1.85 2.05 2.10"
    )
}

// MARK: - Spectrum / Waveform Sample
struct SpectrumBar: Identifiable {
    let id: Int
    var uploadHeight: CGFloat   // 0.0 - 1.0 relative
    var downloadHeight: CGFloat // 0.0 - 1.0 relative
}

// MARK: - Process Traffic Item
struct ProcessItem: Identifiable {
    let id = UUID()
    let name: String
    let iconSystemName: String
    let uploadSpeed: String
    let downloadSpeed: String
    let isHighlighted: Bool
}

// MARK: - Time-Window Rolling Quota Model (7d & 5h, Matching Reference 1)
struct RollingWindowQuota: Identifiable {
    let id = UUID()
    let windowLabel: String    // "7d" or "5h"
    let percent: Double        // 0 to 100
    let resetText: String      // e.g. "resets 6d 12h · 11-21 09:32" or "resets 20m · 20:55"
    let isExhausted: Bool      // percent >= 100
}

struct ModelCategoryQuota: Identifiable {
    let id = UUID()
    let categoryName: String   // "Gemini Models", "Claude and GPT models", "Gemini 4 Argon"
    let windows: [RollingWindowQuota]
}

struct AIProfileQuota {
    var brandName: String          // "Antigravity (反重力)" or "OpenAI Codex"
    var accountEmail: String       // e.g. "s•••••@g••••••"
    var accountType: String        // "Personal Google account" or "OpenAI Developer Account"
    var isActive: Bool             // true
    var lastRefreshed: String      // "1m ago"
    var categories: [ModelCategoryQuota]
}

// MARK: - Network Information
struct NetworkInfo {
    var ssid: String
    var localIPv4: String
    var publicIPv4: String
    var publicIPv6: String
    var countryFlag: String
    var gateway: String
}
