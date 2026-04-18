import SwiftUI

struct DSMeshBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var palette: BackdropPalette = .aurora
    var intensity: Double = 1.0

    enum BackdropPalette {
        case aurora
        case sunset
        case midnight
        case mint

        func colors(scheme: ColorScheme) -> [Color] {
            let dark = scheme == .dark
            switch self {
            case .aurora:
                return dark
                    ? [
                        Color(red: 0.04, green: 0.05, blue: 0.10),
                        Color(red: 0.08, green: 0.06, blue: 0.18),
                        Color(red: 0.04, green: 0.10, blue: 0.16),
                        Color(red: 0.10, green: 0.04, blue: 0.20),
                        Color(red: 0.16, green: 0.10, blue: 0.30),
                        Color(red: 0.04, green: 0.16, blue: 0.22),
                        Color(red: 0.06, green: 0.04, blue: 0.14),
                        Color(red: 0.10, green: 0.06, blue: 0.18),
                        Color(red: 0.04, green: 0.04, blue: 0.10),
                    ]
                    : [
                        Color(red: 0.94, green: 0.97, blue: 1.00),
                        Color(red: 0.86, green: 0.93, blue: 1.00),
                        Color(red: 0.96, green: 0.92, blue: 1.00),
                        Color(red: 0.82, green: 0.95, blue: 0.98),
                        Color(red: 0.92, green: 0.96, blue: 1.00),
                        Color(red: 1.00, green: 0.92, blue: 0.96),
                        Color(red: 0.95, green: 0.99, blue: 0.96),
                        Color(red: 0.88, green: 0.93, blue: 1.00),
                        Color(red: 0.97, green: 0.96, blue: 1.00),
                    ]
            case .sunset:
                return dark
                    ? [
                        Color(red: 0.10, green: 0.04, blue: 0.10),
                        Color(red: 0.18, green: 0.06, blue: 0.14),
                        Color(red: 0.22, green: 0.08, blue: 0.10),
                        Color(red: 0.14, green: 0.04, blue: 0.16),
                        Color(red: 0.26, green: 0.10, blue: 0.18),
                        Color(red: 0.20, green: 0.06, blue: 0.10),
                        Color(red: 0.10, green: 0.04, blue: 0.14),
                        Color(red: 0.16, green: 0.06, blue: 0.12),
                        Color(red: 0.08, green: 0.04, blue: 0.10),
                    ]
                    : [
                        Color(red: 1.00, green: 0.96, blue: 0.92),
                        Color(red: 1.00, green: 0.88, blue: 0.86),
                        Color(red: 1.00, green: 0.80, blue: 0.74),
                        Color(red: 1.00, green: 0.92, blue: 0.84),
                        Color(red: 1.00, green: 0.84, blue: 0.78),
                        Color(red: 0.99, green: 0.78, blue: 0.72),
                        Color(red: 1.00, green: 0.94, blue: 0.90),
                        Color(red: 1.00, green: 0.86, blue: 0.80),
                        Color(red: 1.00, green: 0.92, blue: 0.88),
                    ]
            case .midnight:
                return [
                    Color(red: 0.02, green: 0.03, blue: 0.08),
                    Color(red: 0.04, green: 0.06, blue: 0.12),
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                    Color(red: 0.03, green: 0.04, blue: 0.10),
                    Color(red: 0.08, green: 0.10, blue: 0.20),
                    Color(red: 0.04, green: 0.06, blue: 0.14),
                    Color(red: 0.02, green: 0.04, blue: 0.10),
                    Color(red: 0.04, green: 0.06, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.06),
                ]
            case .mint:
                return dark
                    ? [
                        Color(red: 0.02, green: 0.10, blue: 0.10),
                        Color(red: 0.04, green: 0.16, blue: 0.14),
                        Color(red: 0.06, green: 0.18, blue: 0.20),
                        Color(red: 0.04, green: 0.12, blue: 0.14),
                        Color(red: 0.08, green: 0.20, blue: 0.18),
                        Color(red: 0.06, green: 0.14, blue: 0.16),
                        Color(red: 0.02, green: 0.10, blue: 0.12),
                        Color(red: 0.04, green: 0.14, blue: 0.14),
                        Color(red: 0.02, green: 0.08, blue: 0.10),
                    ]
                    : [
                        Color(red: 0.92, green: 0.99, blue: 0.96),
                        Color(red: 0.84, green: 0.97, blue: 0.92),
                        Color(red: 0.78, green: 0.95, blue: 0.94),
                        Color(red: 0.88, green: 0.97, blue: 0.94),
                        Color(red: 0.82, green: 0.96, blue: 0.96),
                        Color(red: 0.76, green: 0.94, blue: 0.92),
                        Color(red: 0.90, green: 0.98, blue: 0.96),
                        Color(red: 0.84, green: 0.96, blue: 0.94),
                        Color(red: 0.92, green: 0.99, blue: 0.97),
                    ]
            }
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let colors = palette.colors(scheme: scheme)

            ZStack {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: meshPoints(t: t),
                    colors: colors,
                    smoothsColors: true
                )
                .ignoresSafeArea()

                // Floating orb glows
                FloatingOrb(color: DS.Palette.auroraIndigo.opacity(scheme == .dark ? 0.32 : 0.22),
                            size: 360,
                            speed: 0.32,
                            phase: 0,
                            t: t)

                FloatingOrb(color: DS.Palette.auroraTeal.opacity(scheme == .dark ? 0.26 : 0.18),
                            size: 280,
                            speed: 0.42,
                            phase: 1.6,
                            t: t)

                FloatingOrb(color: DS.Palette.auroraPink.opacity(scheme == .dark ? 0.20 : 0.16),
                            size: 220,
                            speed: 0.58,
                            phase: 3.1,
                            t: t)

                // Subtle film grain via noise dots — keep extremely faint for elegance
                LinearGradient(
                    colors: [
                        scheme == .dark ? Color.black.opacity(0.20) : Color.white.opacity(0.30),
                        .clear,
                        scheme == .dark ? Color.black.opacity(0.30) : Color.white.opacity(0.05),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .opacity(intensity)
        }
    }

    private func meshPoints(t: TimeInterval) -> [SIMD2<Float>] {
        let s = Float(0.04)
        let f1 = Float(sin(t * 0.30)) * s
        let f2 = Float(cos(t * 0.36)) * s
        let f3 = Float(sin(t * 0.42)) * s
        let f4 = Float(cos(t * 0.28)) * s
        return [
            SIMD2(0.0,     0.0),
            SIMD2(0.5 + f1, 0.0),
            SIMD2(1.0,     0.0),

            SIMD2(0.0,     0.5 + f2),
            SIMD2(0.5 + f3, 0.5 + f4),
            SIMD2(1.0,     0.5 - f2),

            SIMD2(0.0,     1.0),
            SIMD2(0.5 - f1, 1.0),
            SIMD2(1.0,     1.0),
        ]
    }
}

private struct FloatingOrb: View {
    let color: Color
    let size: CGFloat
    let speed: Double
    let phase: Double
    let t: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w * 0.5 + sin(t * speed + phase) * (w * 0.32)
            let cy = h * 0.45 + cos(t * speed * 0.8 + phase) * (h * 0.22)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .blur(radius: 60)
                .position(x: cx, y: cy)
                .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
