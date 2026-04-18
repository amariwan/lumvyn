import SwiftUI

struct ConflictSection: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Section {
            Picker(LocalizedStringKey("Konfliktlösung"), selection: $settingsStore.conflictResolution) {
                ForEach(ConflictResolution.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        } header: {
            SettingsSectionHeader(title: NSLocalizedString("Konfliktverhalten", comment: ""), systemImage: "arrow.triangle.branch")
        }
    }
}
