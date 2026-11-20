import SwiftUI

// MARK: - Nothing OS / Teenage Engineering Style Dot-Matrix Network Equalizer
// Precision 32-Channel x 7-Row Bottom-Up Spectrum Equalizer (Clean Canvas, Zero Text Collision)
struct WaveformView: View {
    let bars: [SpectrumBar]
    
    private let columnCount = 32
    private let rowCount = 7 // 7 vertical dots per channel, rising from bottom baseline
    
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 2.8
            let colStep = (size.width - dotSize) / CGFloat(columnCount - 1)
            let rowStep = (size.height - dotSize) / CGFloat(rowCount - 1)
            
            for col in 0..<columnCount {
                let x = CGFloat(col) * colStep + (dotSize / 2.0)
                
                // Left 16 channels = TX (Upload), Right 16 channels = RX (Download)
                let barIdx = Int((Double(col) / Double(columnCount)) * Double(bars.count))
                let bar = (barIdx < bars.count) ? bars[barIdx] : SpectrumBar(id: col, uploadHeight: 0.15, downloadHeight: 0.25)
                
                let isUploadChannel = col < (columnCount / 2)
                let heightFraction = isUploadChannel ? bar.uploadHeight : bar.downloadHeight
                
                // Lit count: at least 1 dot on baseline, up to rowCount (7)
                let litCount = min(rowCount, max(1, Int(round(heightFraction * CGFloat(rowCount)))))
                
                for row in 0..<rowCount {
                    let y = size.height - (dotSize / 2.0) - CGFloat(row) * rowStep
                    let dotRect = CGRect(x: x - dotSize / 2.0, y: y - dotSize / 2.0, width: dotSize, height: dotSize)
                    
                    if row < litCount {
                        let color: Color
                        if isUploadChannel {
                            if row < 3 {
                                color = Color.white
                            } else if row < 5 {
                                color = Color(hex: 0xC084FC) // Lilac
                            } else {
                                color = ThemeColors.accentPurple // Vibrant Purple
                            }
                        } else {
                            if row < 2 {
                                color = Color(hex: 0x1FE3D2) // Electric Blue / Cyan
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
                        context.fill(Path(ellipseIn: dotRect), with: .color(ThemeColors.dotInactive))
                    }
                }
            }
        }
        .frame(height: 42)
        .padding(.horizontal, 4)
    }
}
