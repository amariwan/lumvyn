import SwiftUI

struct StorageSection: View {
    @EnvironmentObject private var queueManager: UploadQueueManager
    @State private var showClearConfirm: Bool = false

    var body: some View {
        Section {
            SettingsIconRow(icon: "internaldrive.fill", color: .gray) {
                Text(LocalizedStringKey("Cache-Größe"))
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: queueManager.cacheSizeBytes, countStyle: .file))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button(role: .destructive) {
                withAnimation {
                    queueManager.clearCache()
                }
            } label: {
                Label(LocalizedStringKey("Cache leeren"), systemImage: "trash")
            }
            .disabled(queueManager.cacheSizeBytes == 0)

            SettingsIconRow(icon: "trash.circle.fill", color: .orange) {
                Text(LocalizedStringKey("Ausstehende Löschungen"))
                Spacer()
                if queueManager.isProcessingDeletions {
                    ProgressView()
                        .scaleEffect(0.6, anchor: .center)
                } else {
                    Text("\(queueManager.pendingDeletionCount)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack {
                Button {
                    Task { await queueManager.retryPendingDeletions() }
                } label: {
                    Text(LocalizedStringKey("Löschungen erneut versuchen"))
                }

                Spacer()

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Text(LocalizedStringKey("Lösch-Queue leeren"))
                }
                .disabled(queueManager.pendingDeletionCount == 0)
                .alert(LocalizedStringKey("Alle ausstehenden Löschungen löschen?"), isPresented: $showClearConfirm) {
                    Button(LocalizedStringKey("Löschen"), role: .destructive) {
                        Task { await queueManager.clearPendingDeletionQueue() }
                    }
                    Button(LocalizedStringKey("Abbrechen"), role: .cancel) { }
                }
            }
        } header: {
            SettingsSectionHeader(title: NSLocalizedString("Speicher", comment: "Storage section header"), systemImage: "folder.fill")
        }
    }
}
