import SwiftUI
#if os(iOS)
import UIKit
#endif

struct BottomControlsView: View {
    let currentPage: Int
    let totalPages: Int
    let accentColor: Color
    let pageKind: OnboardingPageKind
    let canProceed: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    let onFinish: () -> Void

    @State private var buttonScale: CGFloat = 1.0

    private var isLastPage: Bool { currentPage == totalPages - 1 }
    private var isSetupPage: Bool { pageKind == .smbSetup }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                if isLastPage { onFinish() } else { onNext() }
            } label: {
                HStack(spacing: 10) {
                    Text(isLastPage ? LocalizedStringKey("Loslegen") : LocalizedStringKey("Weiter"))
                        .font(.headline)
                    Image(systemName: isLastPage ? "checkmark" : "chevron.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(canProceed || !isSetupPage ? .white : .white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: canProceed || !isSetupPage
                            ? [accentColor, accentColor.opacity(0.70)]
                            : [Color.white.opacity(0.07), Color.white.opacity(0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: (canProceed || !isSetupPage) ? accentColor.opacity(0.35) : .clear, radius: 14, x: 0, y: 6)
            }
            .disabled(isSetupPage && !canProceed)
            .scaleEffect(buttonScale)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: canProceed)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isLastPage)
            .onChange(of: canProceed) { newValue in
                guard newValue && isSetupPage else { return }
                withAnimation(.spring(response: 0.22, dampingFraction: 0.38)) { buttonScale = 1.07 }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { buttonScale = 1.0 }
                }
            }

            if !isLastPage {
                Button(action: {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    onSkip()
                }) {
                    HStack(spacing: 4) {
                        Text(isSetupPage ? LocalizedStringKey("Jetzt überspringen") : LocalizedStringKey("Überspringen"))
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white.opacity(0.32))
                }
                .transition(.opacity)
            } else {
                Spacer().frame(height: 20)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: canProceed)
    }
}
