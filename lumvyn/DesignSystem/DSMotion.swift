import SwiftUI

enum DSMotion {
    static let snap         = Animation.spring(response: 0.28, dampingFraction: 0.78)
    static let bouncy       = Animation.spring(response: 0.38, dampingFraction: 0.68)
    static let smooth       = Animation.spring(response: 0.50, dampingFraction: 0.85)
    static let fluid        = Animation.spring(response: 0.62, dampingFraction: 0.78)
    static let hero         = Animation.spring(response: 0.78, dampingFraction: 0.74)
    static let tap          = Animation.spring(response: 0.22, dampingFraction: 0.72)
    static let breathing    = Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)
    static let drift        = Animation.easeInOut(duration: 8.0).repeatForever(autoreverses: true)

    static func stagger(index: Int, base: TimeInterval = 0.05) -> Animation {
        bouncy.delay(base * Double(index))
    }
}

struct AppearStaggerModifier: ViewModifier {
    let index: Int
    let initialOffset: CGFloat
    let scale: CGFloat
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : scale)
            .offset(y: visible ? 0 : initialOffset)
            .blur(radius: visible ? 0 : 6)
            .onAppear {
                withAnimation(DSMotion.stagger(index: index, base: 0.06)) {
                    visible = true
                }
            }
    }
}

extension View {
    func appearStagger(index: Int = 0, offset: CGFloat = 14, scale: CGFloat = 0.92) -> some View {
        modifier(AppearStaggerModifier(index: index, initialOffset: offset, scale: scale))
    }
}

struct PressableScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(DSMotion.tap, value: configuration.isPressed)
            #if os(iOS)
            .onChange(of: configuration.isPressed) { _, pressed in
                if haptic && pressed {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
            #endif
    }
}

extension ButtonStyle where Self == PressableScaleStyle {
    static var pressableScale: PressableScaleStyle { PressableScaleStyle() }
    static func pressableScale(_ scale: CGFloat, haptic: Bool = true) -> PressableScaleStyle {
        PressableScaleStyle(scale: scale, haptic: haptic)
    }
}

struct ParallaxModifier: ViewModifier {
    let strength: CGFloat
    @State private var offset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(Double(-offset.height) * 0.06 * Double(strength)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.6
            )
            .rotation3DEffect(
                .degrees(Double(offset.width) * 0.06 * Double(strength)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        withAnimation(DSMotion.smooth) {
                            offset = CGSize(width: v.translation.width / 4, height: v.translation.height / 4)
                        }
                    }
                    .onEnded { _ in
                        withAnimation(DSMotion.fluid) { offset = .zero }
                    }
            )
    }
}

extension View {
    func parallax(strength: CGFloat = 1.0) -> some View {
        modifier(ParallaxModifier(strength: strength))
    }
}

struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.55)
                        .offset(x: proxy.size.width * phase)
                        .blendMode(.plusLighter)
                        .mask(content)
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                phase = 1.6
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func shimmer(_ active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}
