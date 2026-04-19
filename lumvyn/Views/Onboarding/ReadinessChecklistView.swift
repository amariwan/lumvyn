import SwiftUI
import Combine
import Photos
import UserNotifications

// MARK: - Model

struct ReadinessItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    var status: ItemStatus

    enum ItemStatus {
        case checking
        case ok
        case warning(String)
        case missing(String)
    }

    var isBlocking: Bool {
        if case .missing = status { return true }
        return false
    }
}

// MARK: - ViewModel

@MainActor
final class ReadinessChecker: ObservableObject {
    @Published var items: [ReadinessItem] = []
    @Published var isChecking = true

    func run(settingsStore: SettingsStoreProtocol) async {
        isChecking = true
        items = initialItems()

        await checkPhotoAccess()
        await checkNotifications()
        checkSMBConfig(settingsStore)

        isChecking = false
    }

    // MARK: - Checks

    private func checkPhotoAccess() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        updateItem(id: "photos", status: statusForPhotoAuth(status))

        if status == .notDetermined {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            updateItem(id: "photos", status: statusForPhotoAuth(granted))
        }
    }

    private func statusForPhotoAuth(_ status: PHAuthorizationStatus) -> ReadinessItem.ItemStatus {
        switch status {
        case .authorized:
            return .ok
        case .limited:
            return .warning(NSLocalizedString("ChecklistPhotoLimited", comment: ""))
        case .denied, .restricted:
            return .missing(NSLocalizedString("ChecklistPhotoDenied", comment: ""))
        case .notDetermined:
            return .checking
        @unknown default:
            return .missing(NSLocalizedString("ChecklistPhotoUnknown", comment: ""))
        }
    }

    private func checkNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            updateItem(id: "notifications", status: .ok)
        case .denied:
            updateItem(id: "notifications", status: .warning(NSLocalizedString("ChecklistNotificationsDenied", comment: "")))
        case .notDetermined:
            updateItem(id: "notifications", status: .checking)
            let granted = await requestNotificationAuthorization()
            updateItem(id: "notifications", status: granted
                ? .ok
                : .warning(NSLocalizedString("ChecklistNotificationsDenied", comment: ""))
            )
        @unknown default:
            updateItem(id: "notifications", status: .warning(NSLocalizedString("ChecklistNotificationsDenied", comment: "")))
        }
    }

    private func requestNotificationAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
        }
    }

    private func checkSMBConfig(_ store: SettingsStoreProtocol) {
        let configured = store.config.isValid && store.credentials != nil
        updateItem(id: "smb", status: configured
            ? .ok
            : .missing(NSLocalizedString("ChecklistSMBMissing", comment: ""))
        )
    }



    // MARK: - Helpers

    private func initialItems() -> [ReadinessItem] {
        [
            ReadinessItem(
                id: "photos",
                icon: "photo.on.rectangle",
                title: NSLocalizedString("ChecklistPhotosTitle", comment: ""),
                subtitle: NSLocalizedString("ChecklistPhotosSubtitle", comment: ""),
                status: .checking
            ),
            ReadinessItem(
                id: "notifications",
                icon: "bell.badge",
                title: NSLocalizedString("ChecklistNotificationsTitle", comment: ""),
                subtitle: NSLocalizedString("ChecklistNotificationsSubtitle", comment: ""),
                status: .checking
            ),
            ReadinessItem(
                id: "smb",
                icon: "server.rack",
                title: NSLocalizedString("ChecklistSMBTitle", comment: ""),
                subtitle: NSLocalizedString("ChecklistSMBSubtitle", comment: ""),
                status: .checking
            ),

        ]
    }

    private func updateItem(id: String, status: ReadinessItem.ItemStatus) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            items[idx].status = status
        }
    }
}

// MARK: - View

struct ReadinessChecklistView: View {
    let page: OnboardingPage
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var checker = ReadinessChecker()

    @State private var appeared = false

    var allClear: Bool {
        !checker.isChecking && !checker.items.contains(where: \.isBlocking)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 72)

                CompactPageIcon(page: page)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 24)

                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(page.subtitle)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 28)
                .offset(y: appeared ? 0 : 18)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: appeared)

                Spacer().frame(height: 36)

                VStack(spacing: 12) {
                    ForEach(checker.items) { item in
                        ChecklistRow(item: item, accentColor: page.accentColor)
                    }
                }
                .padding(.horizontal, 20)
                .offset(y: appeared ? 0 : 22)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.18), value: appeared)

                Spacer().frame(height: 32)

                if !checker.isChecking {
                    Group {
                        if allClear {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text(NSLocalizedString("ChecklistAllReady", comment: ""))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.green)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.12)))
                        } else if checker.items.contains(where: \.isBlocking) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(NSLocalizedString("ChecklistHasBlocking", comment: ""))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.orange)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 120)
            }
        }
        .animateOnAppear($appeared, primaryAnimation: .spring(response: 0.6, dampingFraction: 0.65).delay(0.05), onAppearTask: {
            await checker.run(settingsStore: settingsStore)
        })
    }
}

// MARK: - Row

private struct ChecklistRow: View {
    let item: ReadinessItem
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconForeground)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(rowSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer()

            statusBadge
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: statusKey)
    }

    // MARK: Computed

    private var rowSubtitle: String {
        switch item.status {
        case .warning(let msg), .missing(let msg): return msg
        default: return item.subtitle
        }
    }

    private var iconBackground: Color {
        switch item.status {
        case .checking: return Color.white.opacity(0.08)
        case .ok: return Color.green.opacity(0.18)
        case .warning: return Color.orange.opacity(0.18)
        case .missing: return Color.red.opacity(0.18)
        }
    }

    private var iconForeground: Color {
        switch item.status {
        case .checking: return .white.opacity(0.4)
        case .ok: return .green
        case .warning: return .orange
        case .missing: return .red
        }
    }

    private var borderColor: Color {
        switch item.status {
        case .checking: return Color.white.opacity(0.08)
        case .ok: return Color.green.opacity(0.25)
        case .warning: return Color.orange.opacity(0.25)
        case .missing: return Color.red.opacity(0.25)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .checking:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white.opacity(0.5))
                .scaleEffect(0.8)
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .transition(.scale.combined(with: .opacity))
        case .missing:
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var statusKey: Int {
        switch item.status {
        case .checking: return 0
        case .ok: return 1
        case .warning: return 2
        case .missing: return 3
        }
    }
}
