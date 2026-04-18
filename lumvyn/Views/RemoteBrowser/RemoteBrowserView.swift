import SwiftUI

struct RemoteBrowserView: View {
    @EnvironmentObject private var queueManager: UploadQueueManager
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var host: String = ""
    @State private var shares: [SMBShare] = []
    @State private var currentShare: SMBShare? = nil
    @State private var currentPath: String = ""
    @State private var entries: [SMBDirectoryEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField(LocalizedStringKey("Host oder IP-Adresse"), text: $host)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled(true)

                    Button(action: { Task { await loadShares() } }) {
                        Text(LocalizedStringKey("Aktualisieren"))
                    }
                }
                .padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                List {
                    if !shares.isEmpty {
                        Section(LocalizedStringKey("Freigaben")) {
                            ForEach(shares) { share in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(share.name)
                                            .font(.subheadline.weight(.semibold))
                                        if !share.comment.isEmpty {
                                            Text(share.comment)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(action: { Task { await openShare(share) } }) {
                                        Text(LocalizedStringKey("Öffnen"))
                                    }
                                }
                            }
                        }
                    }

                    if currentShare != nil {
                        Section(header: Text("Pfad: \(currentPath.isEmpty ? "/" : currentPath)")) {
                            ForEach(entries) { entry in
                                HStack {
                                    Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                        .foregroundStyle(entry.isDirectory ? .yellow : .secondary)
                                    Text(entry.name)
                                    Spacer()
                                    if entry.isDirectory {
                                        Button(action: { Task { await enterDirectory(entry) } }) {
                                            Text(LocalizedStringKey("Öffnen"))
                                        }
                                    } else {
                                        Button(action: { Task { await downloadFile(entry) } }) {
                                            Text(LocalizedStringKey("Herunterladen"))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Remote‑Browser"))
            .onAppear {
                host = settingsStore.host
                Task { await loadShares() }
            }
            .alert(isPresented: $showError) {
                Alert(title: Text(LocalizedStringKey("Fehler")), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Actions

    private func loadShares() async {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            shares = try await settingsStore.browserClient.listShares(host: host, credentials: settingsStore.credentials)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func openShare(_ share: SMBShare) async {
        currentShare = share
        currentPath = ""
        await loadDirectory(shareName: share.name, path: "")
    }

    private func loadDirectory(shareName: String, path: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await settingsStore.browserClient.listDirectoryItems(host: host, shareName: shareName, path: path, credentials: settingsStore.credentials)
            currentPath = path
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func enterDirectory(_ entry: SMBDirectoryEntry) async {
        guard let share = currentShare else { return }
        let next = currentPath.isEmpty ? entry.name : "\(currentPath)/\(entry.name)"
        await loadDirectory(shareName: share.name, path: next)
    }

    private func downloadFile(_ entry: SMBDirectoryEntry) async {
        guard let share = currentShare else { return }
        let remotePath = currentPath.isEmpty ? entry.name : "\(currentPath)/\(entry.name)"
        do {
            let localURL = try await settingsStore.browserClient.downloadFile(host: host, shareName: share.name, remotePath: remotePath, credentials: settingsStore.credentials)
            // Quick feedback; saving into app cache or offering import could follow.
            errorMessage = String(format: NSLocalizedString("Datei heruntergeladen: %@", comment: "downloaded file"), localURL.lastPathComponent)
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct RemoteBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        RemoteBrowserView()
            .environmentObject(UploadQueueManager(smbClient: SMBClient(), settingsStore: SettingsStore(), remoteIndex: RemoteIndexStore(), remoteDeletionQueue: RemoteDeletionQueue(), inAppNotifications: InAppNotificationCenter.shared))
            .environmentObject(SettingsStore())
            .environmentObject(InAppNotificationCenter.shared)
    }
}
