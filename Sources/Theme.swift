import SwiftUI
import AppKit

// MARK: - Color Hex Extensions
extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xff) / 255.0
        let g = CGFloat((hex >> 8) & 0xff) / 255.0
        let b = CGFloat(hex & 0xff) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Typography (English/Numbers: SF Sans / Chinese: PingFang SC)
extension Font {
    /// Chinese native font using PingFang SC (Apple Native)
    static func pingFangSC(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .bold, .heavy, .black:
            fontName = "PingFangSC-Semibold"
        case .semibold:
            fontName = "PingFangSC-Medium"
        case .medium:
            fontName = "PingFangSC-Medium"
        case .light, .thin, .ultraLight:
            fontName = "PingFangSC-Light"
        default:
            fontName = "PingFangSC-Regular"
        }
        return Font.custom(fontName, size: size)
    }
    
    /// Backward-compatible alias mapping to PingFang SC
    static func oppoSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return pingFangSC(size, weight: weight)
    }
    
    /// English & Numeric font using SF Sans (San Francisco Pro)
    static func sfSans(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        return Font.system(size: size, weight: weight, design: design)
    }
    
    /// Rounded numeric font for numbers & speeds
    static func sfRounded(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        return Font.system(size: size, weight: weight, design: .rounded)
    }
    
    /// Monospaced technical telemetry font
    static func sfMono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        return Font.system(size: size, weight: weight, design: .monospaced)
    }
}

extension NSFont {
    /// Chinese native font using PingFang SC (Apple Native)
    static func pingFangSC(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let fontName: String
        switch weight {
        case .bold, .heavy, .black:
            fontName = "PingFangSC-Semibold"
        case .semibold:
            fontName = "PingFangSC-Medium"
        case .medium:
            fontName = "PingFangSC-Medium"
        case .light, .thin, .ultraLight:
            fontName = "PingFangSC-Light"
        default:
            fontName = "PingFangSC-Regular"
        }
        return NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
    
    /// Backward-compatible alias mapping to PingFang SC
    static func oppoSans(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        return pingFangSC(size, weight: weight)
    }
    
    /// English & Numeric font using SF Sans
    static func sfSans(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: size, weight: weight)
    }
    
    /// Monospaced numeric font
    static func sfMono(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Native macOS Frosted Glass (Visual Effect Blur)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Nothing OS / Teenage Engineering Minimalist Industrial Tokens
struct ThemeColors {
    // ── Airy Frosted Glass & Translucent Background Layering (Figma: rgba(45, 46, 48, 0.85) / #2D2E30 @ 85%)
    static let glassTint = Color(hex: 0x2D2E30, alpha: 0.85)      // Figma panel background
    static let matteBg = glassTint
    static let matteCard = Color(hex: 0x161820, alpha: 0.52)     // Refined translucent smoke tile (neither milky nor pitch black)
    static let matteCardSecondary = Color(hex: 0x1D202A, alpha: 0.42) // Interactive translucent tile
    static let matteCardTertiary = Color(hex: 0x252936, alpha: 0.58)  // Active chip container
    
    // ── Fine Crisp Borders (0.6px translucent light catch)
    static let hairlineBorder = Color.white.opacity(0.11)
    static let hairlineBorderHighlight = Color.white.opacity(0.22)
    static let divider = Color.white.opacity(0.08)
    
    // ── Dot Matrix Display & Progress Bar Track Colors (Nothing Phone / Teenage Engineering Style)
    static let dotInactive = Color.white.opacity(0.07)              // Unlit dot-matrix pixel
    static let trackBackground = Color.white.opacity(0.07)          // Figma white/opacity-70 progress bar track
    static let dotActive = Color.white                              // Pure bright illuminated pixel
    static let dotActiveSubtle = Color(hex: 0xD4D4D8)               // Secondary lit pixel
    static let dotMuted = Color(hex: 0x52525B)                      // Low-signal pixel
    
    // ── Precise Jewel Accents (点缀色 · 仅用于点/标/尖端，不铺满大面积)
    static let accentRed = Color(hex: 0xFF453A)                     // Nothing iconic vermillion red dot
    static let accentCyan = Color(hex: 0x1FE3D2)                    // Updated Cyan (#1FE3D2)
    static let accentPurple = Color(hex: 0x9054FF)                  // Updated Pulse Purple (#9054FF)
    static let accentBlue = Color(hex: 0x1FE3D2)                    // Updated Blue (#1FE3D2)
    static let accentOrange = Color(hex: 0xE46C10)                  // Updated Orange (#E46C10)
    static let accentGreen = Color(hex: 0x30D158)                   // Status normal green dot

    // Figma 93:473 / 101:1514 color refinement, 2026-11-20.
    static let accentViolet = Color(hex: 0x875AF6)
    static let selectionFill = Color(hex: 0x8C87D0, alpha: 31.0 / 255.0)
    static let selectionBorder = Color.black.opacity(41.0 / 255.0)
    static let accountAction = Color(hex: 0x2563EB)
    static let quotaHealthy = Color(hex: 0x57BF79)                 // Figma #57BF79; 50% and above
    static let quotaWarning = Color(hex: 0xD3722F)                 // Figma #D3722F; above 20% and below 50%
    static let quotaWarningText = Color.white                      // Percentage label pure white
    static let quotaCritical = Color(hex: 0xD3422F)                // Figma #D3422F; 20% and below

    // Figma 101:1514 Linear Gradients
    static let quotaGradientHealthy = LinearGradient(
        gradient: Gradient(colors: [Color(hex: 0x1FE3D2), Color(hex: 0x57BF79)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    static let quotaGradientWarning = LinearGradient(
        gradient: Gradient(colors: [Color(hex: 0xDEB546), Color(hex: 0xD3722F)]),
        startPoint: .leading,
        endPoint: .trailing
    )
    static let quotaGradientCritical = LinearGradient(
        gradient: Gradient(colors: [Color(hex: 0xE61616), Color(hex: 0xD3422F)]),
        startPoint: .leading,
        endPoint: .trailing
    )

    
    // ── High-Contrast Industrial Typography
    static let textPrimary = Color(hex: 0xF4F4F5)                   // Solid high-contrast white
    static let textSecondary = Color(hex: 0xA1A1AA)                 // Refined silver gray
    static let textMuted = Color(hex: 0x71717A)                     // Quiet technical slate gray
    
    // ── Compatibility aliases
    static let glassBg = matteBg
    static let glassCard = matteCard
    static let glassCardSecondary = matteCardSecondary
    static let glassBorder = hairlineBorder
    static let purple = accentPurple
    static let purpleLight = Color(hex: 0xC37AFF)
    static let purpleDark = Color(hex: 0x8221D9)
    static let blue = accentBlue
    static let blueLight = accentCyan
    static let blueDark = Color(hex: 0x0284C7)
    static let green = accentGreen
    static let orange = accentOrange
    static let red = accentRed
    static let cyan = accentCyan
}

// MARK: - Nothing / Industrial Card View Modifier (Clean Flat Matte, No Stroke)
struct IndustrialCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var hasHighlight: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ThemeColors.matteCard)
            )
    }
}

// MARK: - Emil Kowalski Spring Press Button Style (:active scale(0.96) with instant response)
struct SpringPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var response: Double = 0.18
    var dampingFraction: Double = 0.70
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: response, dampingFraction: dampingFraction), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SpringPressButtonStyle {
    static var springPress: SpringPressButtonStyle { SpringPressButtonStyle() }
    static func springPress(scale: CGFloat = 0.96) -> SpringPressButtonStyle {
        SpringPressButtonStyle(scale: scale)
    }
}

extension View {
    func industrialCard(cornerRadius: CGFloat = 12, hasHighlight: Bool = false) -> some View {
        self.modifier(IndustrialCardModifier(cornerRadius: cornerRadius, hasHighlight: hasHighlight))
    }
    
    func glassCard(cornerRadius: CGFloat = 12, hasHighlight: Bool = false) -> some View {
        self.modifier(IndustrialCardModifier(cornerRadius: cornerRadius, hasHighlight: hasHighlight))
    }
    
    @ViewBuilder
    func disableFocusRing() -> some View {
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled().focusable(false)
        } else {
            self.focusable(false)
        }
    }
}
