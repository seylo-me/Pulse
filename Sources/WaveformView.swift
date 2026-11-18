import SwiftUI

// MARK: - Nothing OS / Teenage Engineering Style Dot-Matrix Network Equalizer
// Precision 32-Channel x 7-Row Bottom-Up Spectrum Equalizer (Matches Figma 1:1)
struct WaveformView: View {
    let bars: [SpectrumBar]
    
    private let columnCount = 32
    private let rowCount = 7 // 7 vertical dots per channel, rising from bottom baseline
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Top Header: TX Telemetry Label & Technical Spec
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(ThemeColors.accentPurple)
                        .frame(width: 4.5, height: 4.5)
                    Text("TX · 上行遥测")
                        .font(.pingFangSC(8.5, weight: .regular))
                        .foregroundColor(ThemeColors.textMuted)
                }
                
                Spacer()
                
                Text("DOT-MATRIX 32CH")
                    .font(.sfSans(8, weight: .medium, design: .monospaced))
                    .foregroundColor(ThemeColors.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Spacer(minLength: 3)
            
            // ── Center: 32x7 Dot Matrix Canvas (Completely isolated, zero text collision)
            Canvas { context, size in
                let dotSize: CGFloat = 3.0
                let colStep = (size.width - dotSize) / CGFloat(columnCount - 1)
                let rowStep = (size.height - dotSize) / CGFloat(rowCount - 1)
                
                for col in 0..<columnCount {
                    let x = CGFloat(col) * colStep + (dotSize / 2.0)
                    
                    // Determine activity for this column:
                    // Left 16 channels = TX (Upload), Right 16 channels = RX (Download)
                    let barIdx = Int((Double(col) / Double(columnCount)) * Double(bars.count))
                    let bar = (barIdx < bars.count) ? bars[barIdx] : SpectrumBar(id: col, uploadHeight: 0.15, downloadHeight: 0.25)
                    
                    let isUploadChannel = col < (columnCount / 2)
                    let heightFraction = isUploadChannel ? bar.uploadHeight : bar.downloadHeight
                    
                    // Lit count: at least 1 dot on baseline, up to rowCount (7)
                    let litCount = min(rowCount, max(1, Int(round(heightFraction * CGFloat(rowCount)))))
                    
                    for row in 0..<rowCount {
                        // row 0 is bottom, row 6 is top
                        let y = size.height - (dotSize / 2.0) - CGFloat(row) * rowStep
                        let dotRect = CGRect(x: x - dotSize / 2.0, y: y - dotSize / 2.0, width: dotSize, height: dotSize)
                        
                        if row < litCount {
                            // Lit dot color grading based on channel type & height
                            let color: Color
                            if isUploadChannel {
                                // TX: White base -> Lavender mid -> Cyber Purple peak
                                if row < 3 {
                                    color = Color.white
                                } else if row < 5 {
                                    color = Color(hex: 0xC084FC) // Lilac
                                } else {
                                    color = ThemeColors.accentPurple // Vibrant Purple
                                }
                            } else {
                                // RX: Electric Cyan base -> Bright Sky Blue -> Electric Purple peak
                                if row < 2 {
                                    color = Color(hex: 0x38BDF8) // Electric Cyan
                                } else if row < 4 {
                                    color = Color(hex: 0x60A5FA) // Sky Blue
                                } else if row < 5 {
                                    color = Color(hex: 0x818CF8) // Indigo
                                } else {
                                    color = Color(hex: 0xC084FC) // Lilac/Purple peak
                                }
                            }
                            context.fill(Path(ellipseIn: dotRect), with: .color(color))
                        } else {
                            // Unlit dot: technical subtle dark dot
                            context.fill(Path(ellipseIn: dotRect), with: .color(ThemeColors.dotInactive))
                        }
                    }
                }
            }
            .frame(height: 36)
            .padding(.horizontal, 12)
            
            Spacer(minLength: 3)
            
            // ── Bottom Footer: RX Telemetry Label & Unit Spec
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(ThemeColors.accentBlue)
                        .frame(width: 4.5, height: 4.5)
                    Text("RX · 下行遥测")
                        .font(.pingFangSC(8.5, weight: .regular))
                        .foregroundColor(ThemeColors.textMuted)
                }
                
                Spacer()
                
                Text("REALTIME KB/S")
                    .font(.sfSans(8, weight: .medium, design: .monospaced))
                    .foregroundColor(ThemeColors.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(height: 76)
        .background(ThemeColors.matteCardSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ThemeColors.hairlineBorder, lineWidth: 0.8)
        )
    }
}
