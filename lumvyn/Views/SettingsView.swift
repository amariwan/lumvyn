import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var queueManager: UploadQueueManager

    var body: some View {
        Form {
            Section {
                ConnectionStatusBanner(isConfigured: settingsStore.isConfigured, isTesting: settingsStore.isTestingConnection)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
            }

            SMBServerSection()
            UploadBehaviorSection()
            FolderTemplateSection()
            MediaFilterSection()
            SecuritySection()
            ConflictSection()
            StorageSection()
            LanguageSection()
            SaveStatusSection()
        }
        .navigationTitle(LocalizedStringKey("Einstellungen"))
    }
}
