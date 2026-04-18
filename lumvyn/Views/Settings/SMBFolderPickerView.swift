import SwiftUI

// MARK: - Navigation value

private struct BrowseLevel: Hashable {
    let shareName: String
    /// Path relative to the share root. Empty string = share root.
    let subPath: String

    /// Last path component to use as the navigation title.
    var displayName: String {
        guard !subPath.isEmpty else { return shareName }
        return (subPath as NSString).lastPathComponent
    }

    /// Full path stored in `sharePath`: "ShareName" or "ShareName/subfolder/...".
    var fullPath: String {
        subPath.isEmpty ? shareName : "\(shareName)/\(subPath)"
    }

    /// Child level when drilling into `folderName`.
    func child(_ folderName: String) -> BrowseLevel {
        let childSubPath = subPath.isEmpty ? folderName : "\(subPath)/\(folderName)"
        return BrowseLevel(shareName: shareName, subPath: childSubPath)
    }
}

// MARK: - Root picker (share list)

struct SMBFolderPickerView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @Binding var isPresented: Bool

    @State private var navigationPath = NavigationPath()
    @State private var shares: [SMBShare] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle(LocalizedStringKey("Freigabe wählen"))
                .navigationDestination(for: BrowseLevel.self) { level in
                    SMBFolderLevelView(
                        level: level,
                        navigationPath: $navigationPath,
                        onSelect: confirm
                    )
                    .environmentObject(settingsStore)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(LocalizedStringKey("Abbrechen")) { isPresented = false }
                    }
                }
        }
        .task { await loadShares() }
    }

    // MARK: Share list content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(LocalizedStringKey("Freigaben werden geladen…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = errorMessage {
            ContentUnavailableView {
                Label(LocalizedStringKey("Verbindungsfehler"), systemImage: "network.slash")
            } description: {
                Text(err)
            } actions: {
                Button(LocalizedStringKey("Erneut versuchen")) {
                    Task { await loadShares() }
                }
                .buttonStyle(.bordered)
            }
        } else if shares.isEmpty {
            ContentUnavailableView(
                LocalizedStringKey("Keine Freigaben gefunden"),
                systemImage: "folder.badge.questionmark"
            )
        } else {
            List(shares) { share in
                Button {
                    navigationPath.append(BrowseLevel(shareName: share.name, subPath: ""))
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(share.name)
                                    .foregroundStyle(.primary)
                                if !share.comment.isEmpty {
                                    Text(share.comment)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "externaldrive.connected.to.line.below")
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Actions

    private func confirm(_ path: String) {
        settingsStore.sharePath = path
        isPresented = false
    }

    private func loadShares() async {
        isLoading = true
        errorMessage = nil
        do {
            shares = try await settingsStore.browserClient.listShares(
                host: settingsStore.host,
                credentials: settingsStore.credentials
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Folder level view

private struct SMBFolderLevelView: View {
    let level: BrowseLevel
    @Binding var navigationPath: NavigationPath
    let onSelect: (String) -> Void

    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var folders: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        content
            .navigationTitle(level.displayName)
            .task { await loadFolders() }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(LocalizedStringKey("Ordner werden geladen…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = errorMessage {
            ContentUnavailableView {
                Label(LocalizedStringKey("Fehler"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(err)
            } actions: {
                Button(LocalizedStringKey("Erneut versuchen")) {
                    Task { await loadFolders() }
                }
                .buttonStyle(.bordered)
            }
        } else {
            List {
                // Select current folder
                Section {
                    Button {
                        onSelect(level.fullPath)
                    } label: {
                        Label(
                            level.subPath.isEmpty
                                ? LocalizedStringKey("Root dieser Freigabe wählen")
                                : LocalizedStringKey("Diesen Ordner wählen"),
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.blue)
                    }
                }

                // Subfolders
                if !folders.isEmpty {
                    Section(LocalizedStringKey("Unterordner")) {
                        ForEach(folders, id: \.self) { folder in
                            Button {
                                navigationPath.append(level.child(folder))
                            } label: {
                                HStack {
                                    Label(folder, systemImage: "folder.fill")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Section {
                        Label(
                            LocalizedStringKey("Keine Unterordner"),
                            systemImage: "folder"
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func loadFolders() async {
        isLoading = true
        errorMessage = nil
        do {
            folders = try await settingsStore.browserClient.listDirectories(
                host: settingsStore.host,
                shareName: level.shareName,
                path: level.subPath,
                credentials: settingsStore.credentials
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
