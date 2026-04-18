import SwiftUI

struct ConnectionStatusBanner: View {
    let isConfigured: Bool
    var isTesting: Bool = false
    @State private var appeared = false

    private var bannerColor: Color {
        if isTesting { return .blue }
        return isConfigured ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(bannerColor)
                    .frame(width: 10, height: 10)

                if isConfigured {
                    Circle()
                        .stroke(bannerColor.opacity(0.4), lineWidth: 6)
                        .frame(width: 10, height: 10)
                        .scaleEffect(appeared ? 2.2 : 1.0)
                        .opacity(appeared ? 0 : 0.8)
                        .animation(
                            .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                            value: appeared
                        )
                }
            }

            Text(isTesting ? LocalizedStringKey("Verbindung wird getestet…") :
                 (isConfigured ? LocalizedStringKey("SMB-Verbindung konfiguriert") : LocalizedStringKey("Noch nicht konfiguriert")))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(bannerColor)

            Spacer()

            if isTesting {
                ProgressView()
                    .controlSize(.small)
                    .tint(bannerColor)
            } else {
                Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(bannerColor)
            }
        }
        .padding(14)
        .background(bannerColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
