import SwiftUI

struct SMBServerSection: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var showFolderPicker = false

    var body: some View {
        Section {
            SettingsIconRow(icon: "network", color: .blue) {
                TextField(LocalizedStringKey("Host oder IP"), text: $settingsStore.host)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled(true)
            }


            SettingsIconRow(icon: "person.fill", color: .blue) {
                TextField(LocalizedStringKey("Benutzername"), text: $settingsStore.username)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled(true)
            }

            SettingsIconRow(icon: "lock.fill", color: .blue) {
                SecureField(LocalizedStringKey("Passwort"), text: $settingsStore.password)
            }

            SettingsIconRow(icon: "folder.fill.badge.gearshape", color: .blue) {
                HStack {
                    TextField(LocalizedStringKey("Freigabe / Pfad"), text: $settingsStore.sharePath)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled(true)

                    Button {
                        showFolderPicker = true
                    } label: {
                        Image(systemName: "folder.badge.questionmark")
                            .foregroundStyle(Color.blue)
                            .opacity(settingsStore.host.trimmed.isEmpty ? 0.35 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(settingsStore.host.trimmed.isEmpty)
                    .accessibilityLabel(Text(LocalizedStringKey("Ordner durchsuchen")))
                }
            }

            .sheet(isPresented: $showFolderPicker) {
                SMBFolderPickerView(isPresented: $showFolderPicker)
                    .environmentObject(settingsStore)
            }

            HStack {
                Spacer()
                Button {
                    Task { await settingsStore.testConnection() }
                } label: {
                    if settingsStore.isTestingConnection {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LocalizedStringKey("Test läuft…"))
                        }
                    } else {
                        Label(LocalizedStringKey("Verbindung testen"), systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(settingsStore.isTestingConnection)
            }

            if let err = settingsStore.connectionError {
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .transition(.opacity)
            }

            if settingsStore.password.isEmpty,
               settingsStore.hasSavedPassword {
                Label(LocalizedStringKey("Passwort ist gespeichert."), systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            SettingsSectionHeader(title: NSLocalizedString("SMB-Server", comment: ""), systemImage: "server.rack")
        }
    }
}
