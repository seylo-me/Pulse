import SwiftUI

// MARK: - Nothing OS / Teenage Engineering 5x7 LED Dot Matrix Display
struct DotMatrixFont {
    // 5 columns, 7 rows bitmask (bits 4..0: column 0..4)
    static let glyphs: [Character: [UInt8]] = [
        "0": [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
        "1": [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "2": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
        "3": [0x1E, 0x01, 0x01, 0x0E, 0x01, 0x01, 0x1E],
        "4": [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
        "5": [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
        "6": [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
        "7": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
        "8": [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
        "9": [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
        ".": [0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x06],
        ",": [0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x04],
        ":": [0x00, 0x0C, 0x0C, 0x00, 0x0C, 0x0C, 0x00],
        "%": [0x19, 0x1A, 0x04, 0x08, 0x0B, 0x13, 0x00],
        "-": [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00],
        "+": [0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00],
        "/": [0x01, 0x02, 0x04, 0x08, 0x10, 0x00, 0x00],
        "K": [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
        "M": [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
        "G": [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0E],
        "B": [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
        " ": [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    ]
    
    static func bitmap(for char: Character) -> [UInt8] {
        let upper = Character(char.uppercased())
        return glyphs[upper] ?? glyphs[" "]!
    }
}

// MARK: - Single Dot Matrix Character View (5x7)
struct DotMatrixCharView: View {
    let char: Character
    var dotSize: CGFloat = 3.0
    var dotSpacing: CGFloat = 1.4
    var activeColor: Color = .white
    var showGrid: Bool = true
    
    private var rows: [UInt8] {
        DotMatrixFont.bitmap(for: char)
    }
    
    var body: some View {
        VStack(spacing: dotSpacing) {
            ForEach(0..<7, id: \.self) { rowIdx in
                let rowVal = rows[rowIdx]
                HStack(spacing: dotSpacing) {
                    ForEach(0..<5, id: \.self) { colIdx in
                        // Bit 4 is col 0, bit 0 is col 4
                        let bitMask: UInt8 = 1 << (4 - colIdx)
                        let isLit = (rowVal & bitMask) != 0
                        
                        Circle()
                            .fill(isLit ? activeColor : (showGrid ? ThemeColors.dotInactive : Color.clear))
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
    }
}

// MARK: - Multi-Character Dot Matrix Text / Number View (Hardware Accelerated GPU Canvas)
struct DotMatrixTextView: View {
    let text: String
    var dotSize: CGFloat = 3.0
    var dotSpacing: CGFloat = 1.4
    var charSpacing: CGFloat = 3.5
    var activeColor: Color = .white
    var showGrid: Bool = true
    
    var body: some View {
        let chars = Array(text)
        let charWidth = CGFloat(5) * dotSize + CGFloat(4) * dotSpacing
        let charHeight = CGFloat(7) * dotSize + CGFloat(6) * dotSpacing
        let totalWidth = CGFloat(chars.count) * charWidth + CGFloat(max(0, chars.count - 1)) * charSpacing
        
        Canvas { context, size in
            for (charIdx, char) in chars.enumerated() {
                let charOffsetX = CGFloat(charIdx) * (charWidth + charSpacing)
                let rows = DotMatrixFont.bitmap(for: char)
                
                for rowIdx in 0..<7 {
                    let rowVal = rows[rowIdx]
                    let y = CGFloat(rowIdx) * (dotSize + dotSpacing)
                    
                    for colIdx in 0..<5 {
                        let x = charOffsetX + CGFloat(colIdx) * (dotSize + dotSpacing)
                        let bitMask: UInt8 = 1 << (4 - colIdx)
                        let isLit = (rowVal & bitMask) != 0
                        
                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        if isLit {
                            context.fill(Path(ellipseIn: rect), with: .color(activeColor))
                        } else if showGrid {
                            context.fill(Path(ellipseIn: rect), with: .color(ThemeColors.dotInactive))
                        }
                    }
                }
            }
        }
        .frame(width: totalWidth, height: charHeight)
    }
}
