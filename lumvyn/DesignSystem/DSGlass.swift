import SwiftUI

struct GlassCard<Content: View>: View {
    var radius: CGFloat = DS.Radius.lg
    var padding: CGFloat = DS.Spacing.md
    var tint: Color? = nil
    var elevation: DS.ShadowStyle = DS.Shadow.soft
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .background {
                if let tint {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.18), tint.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.plusLighter)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(scheme == .dark ? 0.22 : 0.55),
                                .white.opacity(scheme == .dark ? 0.04 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: DS.Stroke.thin
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .dsShadow(elevation)
    }
}

struct LiquidPill<Content: View>: View {
    var tint: Color = DS.Palette.accent
    var filled: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(filled ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.ultraThinMaterial))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        filled ? Color.white.opacity(0.22) : tint.opacity(0.30),
                        lineWidth: DS.Stroke.thin
                    )
            }
            .dsShadow(filled ? DS.ShadowStyle(color: tint.opacity(0.35), radius: 14, x: 0, y: 6) : DS.Shadow.soft)
    }
}

struct GlassButtonStyle: ButtonStyle {
    var tint: Color = DS.Palette.accent
    var prominent: Bool = false
    var fullWidth: Bool = false

    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(prominent ? .white : tint)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.ultraThinMaterial))
            }
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(
                        prominent ? Color.white.opacity(0.20) : tint.opacity(0.32),
                        lineWidth: DS.Stroke.thin
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .opacity(enabled ? 1.0 : 0.45)
            .dsShadow(
                prominent
                    ? DS.ShadowStyle(color: tint.opacity(0.45), radius: configuration.isPressed ? 8 : 18, x: 0, y: configuration.isPressed ? 3 : 8)
                    : DS.Shadow.soft
            )
            .animation(DSMotion.tap, value: configuration.isPressed)
            #if os(iOS)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && enabled {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
            #endif
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
    static func glass(tint: Color = DS.Palette.accent, prominent: Bool = false, fullWidth: Bool = false) -> GlassButtonStyle {
        GlassButtonStyle(tint: tint, prominent: prominent, fullWidth: fullWidth)
    }
}

struct HeroNumber: View {
    let value: Int
    var label: LocalizedStringKey
    var tint: Color = DS.Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .contentTransition(.numericText(value: Double(value)))
                .animation(DSMotion.bouncy, value: value)
        }
    }
}

struct PulseDot: View {
    var color: Color = DS.Palette.accent
    var size: CGFloat = 8
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: size * 2.4, height: size * 2.4)
                .scaleEffect(pulse ? 1.0 : 0.4)
                .opacity(pulse ? 0.0 : 0.6)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.6), radius: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
