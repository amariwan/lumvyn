import SwiftUI

struct UploadBehaviorSection: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Section {
            SettingsToggleRow(label: LocalizedStringKey("Automatisch hochladen"), icon: "bolt.fill", color: .green, isOn: $settingsStore.autoUploadEnabled)
            SettingsToggleRow(label: LocalizedStringKey("Hintergrund-Upload"), icon: "arrow.up.circle.fill", color: .blue, isOn: $settingsStore.backgroundUploadEnabled)
            SettingsToggleRow(label: LocalizedStringKey("Duplikate erkennen"), icon: "doc.on.doc.fill", color: .teal, isOn: $settingsStore.deduplicationEnabled)
            SettingsToggleRow(label: LocalizedStringKey("Nur WLAN"), icon: "wifi", color: .cyan, isOn: $settingsStore.wifiOnlyUpload)
            SettingsToggleRow(label: LocalizedStringKey("Mobilfunk erlauben"), icon: "antenna.radiowaves.left.and.right", color: .orange, isOn: $settingsStore.allowCellularUpload)

            Picker(selection: $settingsStore.syncMode) {
                ForEach(SyncMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            } label: {
                HStack {
                    Image(systemName: settingsStore.syncMode.systemImage)
                        .foregroundStyle(settingsStore.syncMode == .mirror ? .purple : .indigo)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("Sync-Modus"))
                        Text(syncModeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Picker(LocalizedStringKey("Upload-Zyklus"), selection: $settingsStore.uploadSchedule) {
                ForEach(UploadSchedule.allCases) { schedule in
                    Text(schedule.displayName).tag(schedule)
                }
            }

            Stepper(value: $settingsStore.maxConcurrentUploads, in: 1...5) {
                HStack {
                    Image(systemName: "list.number")
                        .foregroundStyle(.purple)
                        .frame(width: 28)
                    Text(String(format: NSLocalizedString("MaxConcurrentUploads", comment: ""), settingsStore.maxConcurrentUploads))
                }
            }
        } header: {
            SettingsSectionHeader(title: NSLocalizedString("Upload-Verhalten", comment: ""), systemImage: "arrow.up.doc.fill")
        } footer: {
            if settingsStore.syncMode == .mirror {
                Text(LocalizedStringKey("Im Spiegel-Modus werden Dateien auf dem Server gelöscht, wenn sie aus der lokalen Bibliothek gelöscht werden. Ein Sicherheitsschwellenwert verhindert versehentliche Massenlöschungen."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var syncModeDescription: String {
        switch settingsStore.syncMode {
        case .backup:
            return NSLocalizedString("Nur hochladen, nie löschen", comment: "Sync mode backup description")
        case .mirror:
            return NSLocalizedString("Server spiegelt lokale Bibliothek genau", comment: "Sync mode mirror description")
        }
    }
}
