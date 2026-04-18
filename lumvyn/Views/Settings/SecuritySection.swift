import SwiftUI

struct SecuritySection: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Section {
            SettingsToggleRow(label: LocalizedStringKey("Verschlüsselung"), icon: "lock.shield.fill", color: .red, isOn: $settingsStore.encryptionEnabled)

            if settingsStore.encryptionEnabled {
                SettingsIconRow(icon: "key.horizontal.fill", color: .red) {
                    SecureField(LocalizedStringKey("Verschlüsselungs-Passwort"), text: $settingsStore.encryptionPassword)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

        } header: {
            SettingsSectionHeader(title: NSLocalizedString("Sicherheit", comment: ""), systemImage: "shield.fill")
        }
    }
}
