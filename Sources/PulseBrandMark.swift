import SwiftUI

/// Resolution-independent brand artwork, fitted to its visible bounds.
struct PulseBrandMark: View {
    var tint: Color = .white
    var minimumDotDiameter: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let bounds = PulseBrandGeometry.bounds
            let scale = min(size.width / bounds.width, size.height / bounds.height)
            let origin = CGPoint(
                x: (size.width - bounds.width * scale) / 2,
                y: (size.height - bounds.height * scale) / 2
            )

            for dot in PulseBrandGeometry.dots {
                let diameter = max(dot.diameter * scale, minimumDotDiameter)
                let center = CGPoint(
                    x: origin.x + (dot.rect.midX - bounds.minX) * scale,
                    y: origin.y + (dot.rect.midY - bounds.minY) * scale
                )
                let rect = CGRect(
                    x: center.x - diameter / 2,
                    y: center.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(dot.opacity)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Shared brand badge used by both popup headers.
struct PulseBrandBadge: View {
    var body: some View {
        PulseBrandMark(minimumDotDiameter: 0.4)
            .frame(width: 23, height: 26)
            .frame(width: 32, height: 32)
            .background(ThemeColors.matteCardSecondary, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ThemeColors.hairlineBorder, lineWidth: 0.8)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pulse")
    }
}
