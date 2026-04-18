import SwiftUI

struct AnimatedBackground: View {
    let page: OnboardingPage
    @State private var animating = false

    var body: some View {
        ZStack {
            LinearGradient(colors: page.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(page.accentColor.opacity(0.22))
                .frame(width: 380).blur(radius: 90)
                .offset(x: animating ? -60 : -115, y: animating ? -210 : -275)
                .animation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true), value: animating)

            Circle()
                .fill(page.accentColor.opacity(0.16))
                .frame(width: 280).blur(radius: 75)
                .offset(x: animating ? 110 : 165, y: animating ? 260 : 335)
                .animation(.easeInOut(duration: 5.8).repeatForever(autoreverses: true), value: animating)

            Circle()
                .fill(page.accentColor.opacity(0.13))
                .frame(width: 220).blur(radius: 65)
                .offset(x: animating ? 135 : 75, y: animating ? -305 : -240)
                .animation(.easeInOut(duration: 6.6).repeatForever(autoreverses: true), value: animating)

            // Bottom depth vignette
            LinearGradient(
                colors: [.clear, .black.opacity(0.30)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .onAppear { animating = true }
    }
}
