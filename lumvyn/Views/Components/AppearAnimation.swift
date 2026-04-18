import SwiftUI

struct AppearAnimation: ViewModifier {
    @Binding var appeared: Bool
    var primaryAnimation: Animation = .spring(response: 0.6, dampingFraction: 0.65).delay(0.05)
    var secondaryBindings: [Binding<Bool>] = []
    var secondaryDelay: Double = 0.4
    var onAppearTask: (() async -> Void)? = nil

    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(primaryAnimation) { appeared = true }

                if !secondaryBindings.isEmpty {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(secondaryDelay * 1_000_000_000))
                        for b in secondaryBindings { b.wrappedValue = true }
                        if let t = onAppearTask { await t() }
                    }
                } else if let t = onAppearTask {
                    Task { await t() }
                }
            }
            .onDisappear { appeared = false }
    }
}

extension View {
    func animateOnAppear(
        _ appeared: Binding<Bool>,
        secondaryBindings: [Binding<Bool>] = [],
        secondaryDelay: Double = 0.4,
        primaryAnimation: Animation = .spring(response: 0.6, dampingFraction: 0.65).delay(0.05),
        onAppearTask: (() async -> Void)? = nil
    ) -> some View {
        modifier(AppearAnimation(appeared: appeared, primaryAnimation: primaryAnimation, secondaryBindings: secondaryBindings, secondaryDelay: secondaryDelay, onAppearTask: onAppearTask))
    }
}
