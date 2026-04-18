import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false
    @State private var iconBounce = false
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                // Floating ambient particles
                FloatingParticle(color: page.accentColor.opacity(0.38), size: 6,
                                 x: -68, y: -46, dx: -10, dy: -12, duration: 2.6)
                FloatingParticle(color: page.accentColor.opacity(0.22), size: 4,
                                 x: 58, y: 34, dx: 11, dy: 9, duration: 2.1)
                FloatingParticle(color: page.accentColor.opacity(0.30), size: 7,
                                 x: -26, y: 66, dx: 7, dy: -9, duration: 3.1)

                Circle()
                    .stroke(page.accentColor.opacity(glowPulse ? 0.45 : 0.12), lineWidth: 1.5)
                    .frame(width: 148, height: 148)
                    .scaleEffect(glowPulse ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)
                Circle()
                    .fill(LinearGradient(colors: [page.accentColor, page.accentColor.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 104, height: 104)
                    .shadow(color: page.accentColor.opacity(0.4), radius: 24, x: 0, y: 8)
                Image(systemName: page.systemImage)
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(iconBounce ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: iconBounce)
            }
            .scaleEffect(appeared ? 1.0 : 0.6)
            .opacity(appeared ? 1.0 : 0)

            Spacer().frame(height: 48)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                Text(page.subtitle)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .offset(y: appeared ? 0 : 14)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: appeared)
            }
            .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
        .animateOnAppear($appeared, secondaryBindings: [$glowPulse, $iconBounce], secondaryDelay: 0.4, primaryAnimation: .spring(response: 0.6, dampingFraction: 0.65).delay(0.05))
    }
}

// MARK: - Floating particle

private struct FloatingParticle: View {
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    let duration: Double
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: x + (animate ? dx : 0), y: y + (animate ? dy : 0))
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

struct CompactPageIcon: View {
    let page: OnboardingPage
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(page.accentColor.opacity(pulse ? 0.45 : 0.12), lineWidth: 1.5)
                .frame(width: 100, height: 100)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(LinearGradient(colors: [page.accentColor, page.accentColor.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 76, height: 76)
                .shadow(color: page.accentColor.opacity(0.45), radius: 20, x: 0, y: 8)
            Image(systemName: page.systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .onAppear { pulse = true }
    }
}
