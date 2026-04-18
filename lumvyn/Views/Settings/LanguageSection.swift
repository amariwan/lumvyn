import SwiftUI

struct LanguageSection: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    private struct LanguageOption: Identifiable {
        let id: String?
        let displayKey: String
    }

    private let options: [LanguageOption] = [
        LanguageOption(id: nil,  displayKey: "System"),
        LanguageOption(id: "de", displayKey: "Deutsch"),
        LanguageOption(id: "en", displayKey: "English")
    ]

    var body: some View {
        Section {
            Picker(LocalizedStringKey("Sprache"), selection: $settingsStore.selectedLanguage) {
                ForEach(options) { option in
                    Text(LocalizedStringKey(option.displayKey)).tag(option.id)
                }
            }

            Text(LocalizedStringKey("SprachhinweisNeustart"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            SettingsSectionHeader(title: NSLocalizedString("Sprache", comment: "Language section header"), systemImage: "globe")
        }
        .onChange(of: settingsStore.selectedLanguage) { newValue in
            Bundle.setLanguage(newValue)
        }
    }
}
