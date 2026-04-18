import SwiftUI

struct SaveStatusSection: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Section {
            if settingsStore.isConfigured {
                Label(LocalizedStringKey("Konfiguration wird automatisch gespeichert."), systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Label(LocalizedStringKey("Bitte alle Felder ausfüllen, um Uploads zu aktivieren."), systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
