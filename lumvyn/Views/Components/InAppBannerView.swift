import SwiftUI

struct InAppBannerView: View {
    @EnvironmentObject var center: InAppNotificationCenter

    var body: some View {
        if let n = center.current {
            VStack {
                HStack(spacing: 12) {
                    icon(for: n.type)
                        .font(.system(size: 18, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(n.title).bold().lineLimit(1)
                        if let msg = n.message {
                            Text(msg).font(.subheadline).lineLimit(2)
                        }
                    }
                    Spacer()
                    Button(action: { center.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.9))
                            .padding(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .foregroundColor(.white)
                .background(backgroundColor(for: n.type))
                .cornerRadius(10)
                .shadow(radius: 8)
                .padding([.horizontal, .top])

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(1000)
        }
    }

    @ViewBuilder
    func icon(for type: InAppNotificationType) -> some View {
        switch type {
        case .info: Image(systemName: "info.circle")
        case .success: Image(systemName: "checkmark.seal.fill")
        case .warning: Image(systemName: "exclamationmark.triangle.fill")
        case .error: Image(systemName: "xmark.octagon.fill")
        }
    }

    func backgroundColor(for type: InAppNotificationType) -> Color {
        switch type {
        case .info: return Color.blue
        case .success: return Color.green
        case .warning: return Color.orange
        case .error: return Color.red
        }
    }
}

struct InAppBannerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InAppBannerView()
                .environmentObject(InAppNotificationCenter.shared)
                .onAppear {
                    InAppNotificationCenter.shared.show(title: "Test", message: "Deletion failed, queued for retry", type: .warning, duration: 3)
                }
        }
    }
}
