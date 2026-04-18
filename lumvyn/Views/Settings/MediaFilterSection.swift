import SwiftUI

struct MediaFilterSection: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Section {
            Picker(LocalizedStringKey("Medientyp"), selection: $settingsStore.mediaTypeFilter) {
                ForEach(MediaTypeFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }

            Picker(LocalizedStringKey("Zeitraum"), selection: $settingsStore.dateRangeType) {
                ForEach(DateRangeType.allCases) { rangeType in
                    Text(rangeType.displayName).tag(rangeType)
                }
            }

            if settingsStore.dateRangeType == .custom {
                DatePicker(LocalizedStringKey("Startdatum"), selection: Binding($settingsStore.customDateRangeStart, replacingNilWith: Date()), displayedComponents: .date)
                DatePicker(LocalizedStringKey("Enddatum"), selection: Binding($settingsStore.customDateRangeEnd, replacingNilWith: Date()), displayedComponents: .date)
            }

            SettingsToggleRow(label: LocalizedStringKey("Album-Filter"), icon: "rectangle.stack.fill", color: .pink, isOn: $settingsStore.albumFilterEnabled)

            if settingsStore.albumFilterEnabled {
                HStack {
                    Image(systemName: "text.justify")
                        .foregroundStyle(.pink)
                        .frame(width: 28)
                    TextField(LocalizedStringKey("Albumnamen, getrennt durch Kommas"), text: Binding(
                        get: { settingsStore.selectedAlbums.joined(separator: ", ") },
                        set: { settingsStore.selectedAlbums = $0.split(separator: ",").map { String($0).trimmed } }
                    ))
                    .autocorrectionDisabled(true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        } header: {
            SettingsSectionHeader(title: NSLocalizedString("Medienfilter", comment: ""), systemImage: "camera.filters")
        }
    }
}
