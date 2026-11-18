import Foundation

/// Approved Figma icon, file faHm9AZ5x2WNZhivQ7mrUr, node 56:286.
/// Coordinates and opacity come directly from its 91 editable ellipses.
/// Shared by the native UI and icon exporter so the artwork stays identical.
enum PulseBrandGeometry {
    struct Dot {
        let x: CGFloat
        let y: CGFloat
        let diameter: CGFloat
        let opacity: Double

        var rect: CGRect { CGRect(x: x, y: y, width: diameter, height: diameter) }
    }

    static let canvasSize: CGFloat = 1024
    static let appMarkScale: CGFloat = 1.18

    static let dots: [Dot] = [
        Dot(x: 507.7160, y: 288.4760, diameter: 8.5680, opacity: 0.643137),
        Dot(x: 470.0560, y: 310.4560, diameter: 8.1760, opacity: 0.729412),
        Dot(x: 545.6840, y: 310.4840, diameter: 8.1760, opacity: 0.670588),
        Dot(x: 431.9200, y: 331.6800, diameter: 9.0160, opacity: 0.615686),
        Dot(x: 507.7160, y: 332.1840, diameter: 8.5680, opacity: 0.627451),
        Dot(x: 584.3800, y: 333.3600, diameter: 6.6640, opacity: 0.721569),
        Dot(x: 394.3440, y: 354.1920, diameter: 8.1760, opacity: 0.674510),
        Dot(x: 470.2520, y: 354.2200, diameter: 7.6720, opacity: 0.670588),
        Dot(x: 545.4880, y: 354.1920, diameter: 8.5680, opacity: 0.627451),
        Dot(x: 621.5360, y: 354.1920, diameter: 8.1760, opacity: 0.635294),
        Dot(x: 504.4120, y: 372.4760, diameter: 15.3440, opacity: 1.000000),
        Dot(x: 356.0400, y: 375.5280, diameter: 8.5680, opacity: 0.639216),
        Dot(x: 431.9760, y: 375.4440, diameter: 9.0160, opacity: 0.592157),
        Dot(x: 583.8480, y: 376.2840, diameter: 7.6720, opacity: 0.674510),
        Dot(x: 659.3640, y: 375.8920, diameter: 8.1760, opacity: 0.654902),
        Dot(x: 466.4160, y: 394.0080, diameter: 15.8480, opacity: 1.000000),
        Dot(x: 542.5200, y: 394.4560, diameter: 15.1200, opacity: 0.988235),
        Dot(x: 318.9400, y: 397.5080, diameter: 8.1760, opacity: 0.698039),
        Dot(x: 394.4840, y: 397.5360, diameter: 8.1760, opacity: 0.717647),
        Dot(x: 621.4240, y: 397.5080, diameter: 8.1760, opacity: 0.662745),
        Dot(x: 697.1920, y: 397.5080, diameter: 8.1760, opacity: 0.674510),
        Dot(x: 500.0440, y: 411.9000, diameter: 23.6880, opacity: 1.000000),
        Dot(x: 428.4760, y: 415.8760, diameter: 15.8480, opacity: 1.000000),
        Dot(x: 580.3200, y: 416.3520, diameter: 14.8960, opacity: 1.000000),
        Dot(x: 356.2640, y: 419.4040, diameter: 8.1760, opacity: 0.674510),
        Dot(x: 659.9520, y: 420.0480, diameter: 7.1680, opacity: 0.709804),
        Dot(x: 462.4960, y: 433.8800, diameter: 23.3520, opacity: 1.000000),
        Dot(x: 538.1800, y: 433.8800, diameter: 23.3520, opacity: 1.000000),
        Dot(x: 390.8440, y: 437.8560, diameter: 15.1200, opacity: 1.000000),
        Dot(x: 618.3160, y: 438.0240, diameter: 14.8960, opacity: 0.980392),
        Dot(x: 318.9120, y: 441.6640, diameter: 8.1760, opacity: 0.752941),
        Dot(x: 697.6120, y: 441.7480, diameter: 7.6720, opacity: 0.686275),
        Dot(x: 424.2200, y: 455.4400, diameter: 24.1360, opacity: 1.000000),
        Dot(x: 499.9040, y: 455.4400, diameter: 24.1360, opacity: 1.000000),
        Dot(x: 575.6160, y: 455.3000, diameter: 24.3040, opacity: 1.000000),
        Dot(x: 352.9040, y: 459.6680, diameter: 15.3440, opacity: 1.000000),
        Dot(x: 656.1440, y: 459.9760, diameter: 14.8960, opacity: 1.000000),
        Dot(x: 386.2240, y: 477.0840, diameter: 24.5840, opacity: 1.000000),
        Dot(x: 462.0760, y: 477.3080, diameter: 24.1360, opacity: 1.000000),
        Dot(x: 537.8160, y: 477.3640, diameter: 24.0240, opacity: 1.000000),
        Dot(x: 613.8080, y: 477.4480, diameter: 23.6880, opacity: 1.000000),
        Dot(x: 318.7160, y: 484.7560, diameter: 8.5680, opacity: 0.701961),
        Dot(x: 697.2200, y: 485.1480, diameter: 8.5680, opacity: 0.658824),
        Dot(x: 424.3320, y: 499.2320, diameter: 23.8560, opacity: 1.000000),
        Dot(x: 575.5320, y: 498.9800, diameter: 24.4720, opacity: 1.000000),
        Dot(x: 353.0440, y: 503.7680, diameter: 14.8960, opacity: 1.000000),
        Dot(x: 504.4680, y: 503.6840, diameter: 15.1200, opacity: 1.000000),
        Dot(x: 656.1440, y: 503.7960, diameter: 14.8960, opacity: 1.000000),
        Dot(x: 386.4760, y: 521.0160, diameter: 24.0240, opacity: 1.000000),
        Dot(x: 613.9760, y: 521.3240, diameter: 23.2400, opacity: 1.000000),
        Dot(x: 466.7520, y: 525.3560, diameter: 15.3440, opacity: 1.000000),
        Dot(x: 542.3800, y: 525.3280, diameter: 15.3440, opacity: 1.000000),
        Dot(x: 318.8560, y: 528.8840, diameter: 8.1760, opacity: 0.823529),
        Dot(x: 697.2200, y: 528.9400, diameter: 8.1760, opacity: 0.764706),
        Dot(x: 353.1000, y: 547.1680, diameter: 15.1200, opacity: 1.000000),
        Dot(x: 428.9800, y: 547.5320, diameter: 14.6160, opacity: 1.000000),
        Dot(x: 580.3480, y: 547.3360, diameter: 14.8960, opacity: 1.000000),
        Dot(x: 655.9480, y: 547.0280, diameter: 15.3440, opacity: 1.000000),
        Dot(x: 507.7160, y: 550.6120, diameter: 8.5680, opacity: 0.678431),
        Dot(x: 390.8720, y: 569.2040, diameter: 15.1200, opacity: 0.996078),
        Dot(x: 618.3440, y: 569.4280, diameter: 14.8960, opacity: 1.000000),
        Dot(x: 470.3080, y: 572.7320, diameter: 7.6720, opacity: 0.717647),
        Dot(x: 545.6000, y: 572.6760, diameter: 8.1760, opacity: 0.666667),
        Dot(x: 697.3040, y: 572.7600, diameter: 8.1760, opacity: 0.674510),
        Dot(x: 319.0520, y: 573.2080, diameter: 7.6720, opacity: 0.709804),
        Dot(x: 356.3200, y: 593.9280, diameter: 8.5680, opacity: 0.647059),
        Dot(x: 432.0600, y: 593.9280, diameter: 8.5680, opacity: 0.607843),
        Dot(x: 507.7160, y: 593.9280, diameter: 8.5680, opacity: 0.588235),
        Dot(x: 583.8480, y: 594.4040, diameter: 7.1680, opacity: 0.690196),
        Dot(x: 659.8960, y: 594.2640, diameter: 7.6720, opacity: 0.678431),
        Dot(x: 318.9400, y: 616.1320, diameter: 8.1760, opacity: 0.705882),
        Dot(x: 394.5960, y: 616.5520, diameter: 7.6720, opacity: 0.717647),
        Dot(x: 470.1960, y: 616.5240, diameter: 7.6720, opacity: 0.682353),
        Dot(x: 545.6560, y: 616.1600, diameter: 8.1760, opacity: 0.647059),
        Dot(x: 621.4240, y: 616.1040, diameter: 8.1760, opacity: 0.631373),
        Dot(x: 697.5560, y: 616.5520, diameter: 7.6720, opacity: 0.682353),
        Dot(x: 355.9000, y: 638.0840, diameter: 8.5680, opacity: 0.666667),
        Dot(x: 432.5920, y: 638.4480, diameter: 7.6720, opacity: 0.611765),
        Dot(x: 508.1640, y: 638.5040, diameter: 7.6720, opacity: 0.611765),
        Dot(x: 583.8200, y: 638.7560, diameter: 7.1680, opacity: 0.690196),
        Dot(x: 659.8680, y: 639.0360, diameter: 6.6640, opacity: 0.694118),
        Dot(x: 394.4280, y: 660.2880, diameter: 8.1760, opacity: 0.713726),
        Dot(x: 470.0560, y: 660.2880, diameter: 8.1760, opacity: 0.674510),
        Dot(x: 545.6280, y: 660.2600, diameter: 8.1760, opacity: 0.639216),
        Dot(x: 621.3960, y: 660.2880, diameter: 8.1760, opacity: 0.607843),
        Dot(x: 432.1160, y: 681.9600, diameter: 8.5680, opacity: 0.564706),
        Dot(x: 507.7440, y: 681.9880, diameter: 8.5680, opacity: 0.549020),
        Dot(x: 583.8480, y: 682.9400, diameter: 7.1680, opacity: 0.631373),
        Dot(x: 469.5240, y: 703.1840, diameter: 9.0160, opacity: 0.694118),
        Dot(x: 545.5160, y: 703.6320, diameter: 8.5680, opacity: 0.654902),
        Dot(x: 507.7160, y: 725.2200, diameter: 8.5680, opacity: 0.643137),
    ]

    static let bounds = dots.reduce(CGRect.null) { $0.union($1.rect) }

    static func appRect(for dot: Dot) -> CGRect {
        let center = canvasSize / 2
        return CGRect(
            x: center + (dot.x - center) * appMarkScale,
            y: center + (dot.y - center) * appMarkScale,
            width: dot.diameter * appMarkScale,
            height: dot.diameter * appMarkScale
        )
    }
}

