import SwiftUI

struct FolderTemplateSection: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    private let presets: [String] = [
        "{year}/{month}",
        "{year}/{month}/{day}",
        "{year}",
        "{album}",
        "{mediaType}/{year}/{month}"
    ]

    var body: some View {
        Section {
            TextField(
                LocalizedStringKey("Ordner-Vorlage"),
                text: $settingsStore.folderTemplate,
                prompt: Text(verbatim: FolderTemplateResolver.defaultTemplate)
            )
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled(true)
            .font(Font.system(.body, design: .monospaced))

            Picker(LocalizedStringKey("Vorlage wählen"), selection: presetBinding) {
                Text(LocalizedStringKey("Benutzerdefiniert")).tag("")
                ForEach(presets, id: \.self) { preset in
                    Text(preset).tag(preset)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LocalizedStringKey("Vorschau"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(previewText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text(LocalizedStringKey("OrdnerVorlageHinweis"))
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            SettingsSectionHeader(
                title: NSLocalizedString("Ordnerstruktur", comment: "Folder structure settings header"),
                systemImage: "folder"
            )
        }
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: { presets.contains(settingsStore.folderTemplate) ? settingsStore.folderTemplate : "" },
            set: { newValue in
                guard !newValue.isEmpty else { return }
                settingsStore.folderTemplate = newValue
            }
        )
    }

    private var previewText: String {
        let path = FolderTemplateResolver.previewPath(template: settingsStore.folderTemplate)
        let arrow = path.isEmpty ? "/" : "\(path)/"
        return "→ \(arrow)IMG_1234.jpg"
    }
}
