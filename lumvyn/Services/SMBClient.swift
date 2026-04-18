import Foundation
import Network
import os

#if canImport(AMSMB2)
import AMSMB2
#endif

// MARK: - Errors

enum SMBClientError: LocalizedError {
    case notConfigured
    case connectionFailed(Error)
    case timedOut(host: String)
    case uploadFailed(Error)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return NSLocalizedString("SMB not configured", comment: "SMB error: not configured")
        case .connectionFailed(let error):
            return error.localizedDescription
        case .timedOut(let host):
            return String(format: NSLocalizedString("Connection to %@ timed out", comment: "SMB error: timed out"), host)
        case .uploadFailed(let error):
            return error.localizedDescription
        case .unavailable:
            return NSLocalizedString("SMB upload support is not available in this build", comment: "SMB error: library unavailable")
        }
    }
}

// MARK: - Connection Status

enum SMBConnectionStatus: Equatable {
    case unknown
    case connecting
    case notConfigured
    case timedOut(host: String)
    case unreachable(String?)
    case portOpen
    case authenticated
    case ready
    case accessDenied
    case shareNotFound
    case failed(String)

    var message: String? {
        switch self {
        case .unknown: return nil
        case .connecting: return NSLocalizedString("Verbinde…", comment: "SMB status: connecting")
        case .notConfigured: return NSLocalizedString("SMB not configured", comment: "SMB status: not configured")
        case .timedOut(let host): return String(format: NSLocalizedString("Connection to %@ timed out", comment: "SMB status: timed out"), host)
        case .unreachable(let msg): return msg
        case .portOpen: return nil
        case .authenticated: return nil
        case .ready: return nil
        case .accessDenied: return NSLocalizedString("Authentication failed", comment: "SMB status: access denied")
        case .shareNotFound: return NSLocalizedString("Share not found", comment: "SMB status: share not found")
        case .failed(let msg): return msg
        }
    }
}

// MARK: - Share Model

struct SMBShare: Identifiable, Sendable {
    let name: String
    let comment: String
    var id: String { name }
}

struct SMBDirectoryEntry: Identifiable, Sendable {
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let modifiedAt: Date?
    var id: String { name }

    init(name: String, isDirectory: Bool, size: Int64? = nil, modifiedAt: Date? = nil) {
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

protocol SMBClientProtocol: AnyObject {
    func upload(
        fileURL: URL,
        to remotePath: String,
        host: String,
        sharePath: String,
        credentials: SMBCredentials,
        conflictResolution: ConflictResolution,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> String

    func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async throws
    func connectionStatus(host: String, sharePath: String, credentials: SMBCredentials?) async -> SMBConnectionStatus
    func probeWrite(host: String, sharePath: String, credentials: SMBCredentials) async throws

    func listShares(host: String, credentials: SMBCredentials?) async throws -> [SMBShare]
    func listDirectories(host: String, shareName: String, path: String, credentials: SMBCredentials?) async throws -> [String]
    func listDirectoryItems(host: String, shareName: String, path: String, credentials: SMBCredentials?) async throws -> [SMBDirectoryEntry]
    func deleteRemoteItem(host: String, sharePath: String, remotePath: String, credentials: SMBCredentials?) async throws

    func downloadFile(host: String, shareName: String, remotePath: String, credentials: SMBCredentials?) async throws -> URL

    func ensureDirectory(
        host: String,
        sharePath: String,
        remoteDirectory: String,
        credentials: SMBCredentials
    ) async throws
}

extension SMBClientProtocol {
    func ensureDirectory(
        host: String,
        sharePath: String,
        remoteDirectory: String,
        credentials: SMBCredentials
    ) async throws {}

    func listShares(host: String, credentials: SMBCredentials?) async throws -> [SMBShare] { [] }

    func listDirectories(host: String, shareName: String, path: String, credentials: SMBCredentials?) async throws -> [String] { [] }

    func listDirectoryItems(host: String, shareName: String, path: String, credentials: SMBCredentials?) async throws -> [SMBDirectoryEntry] { [] }

    func deleteRemoteItem(host: String, sharePath: String, remotePath: String, credentials: SMBCredentials?) async throws {}

    func downloadFile(host: String, shareName: String, remotePath: String, credentials: SMBCredentials?) async throws -> URL {
        throw SMBClientError.unavailable
    }
}

final class SMBClient: SMBClientProtocol {
    private func makeURL(for host: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = host
        guard let url = components.url else { throw SMBClientError.notConfigured }
        return url
    }
    func upload(
        fileURL: URL,
        to remotePath: String,
        host: String,
        sharePath: String,
        credentials: SMBCredentials,
        conflictResolution: ConflictResolution,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> String {
        try Task.checkCancellation()

        #if canImport(AMSMB2)
        let result = try await withClient(host: host, sharePath: sharePath, credentials: credentials) { client -> String in
            // -- Conflict resolution ------------------------------------------------
            let finalPath: String
            switch conflictResolution {
            case .skip:
                if (try? await client.attributesOfItem(atPath: remotePath)) != nil {
                    progress(1.0)
                    return remotePath
                }
                finalPath = remotePath

            case .overwrite:
                finalPath = remotePath

            case .rename:
                if (try? await client.attributesOfItem(atPath: remotePath)) != nil {
                    var counter = 1
                    var candidate = Self.renamedPath(remotePath, counter: counter)
                    while (try? await client.attributesOfItem(atPath: candidate)) != nil, counter < 9_999 {
                        counter += 1
                        candidate = Self.renamedPath(remotePath, counter: counter)
                    }
                    finalPath = candidate
                } else {
                    finalPath = remotePath
                }
            }

            // -- Upload -------------------------------------------------------------
            let totalBytes = try self.fileSize(fileURL)

            do {
                try await client.uploadItem(at: fileURL, toPath: finalPath) { bytes -> Bool in
                    guard !Task.isCancelled else { return false }
                    progress(totalBytes > 0 ? Double(bytes) / Double(totalBytes) : 0)
                    return true
                }
                progress(1.0)
                return finalPath
            } catch {
                let ns = error as NSError
                let desc = ns.localizedDescription.lowercased()
                let isAccessDenied = ns.domain == NSPOSIXErrorDomain && ns.code == 13
                    || desc.contains("access") && desc.contains("denied")
                    || desc.contains("status_access_denied")
                    || desc.contains("0xc000022")

                if isAccessDenied {
                    let tempPath = Self.tempUploadPath(finalPath)
                    do {
                        try await client.uploadItem(at: fileURL, toPath: tempPath) { bytes -> Bool in
                            guard !Task.isCancelled else { return false }
                            progress(totalBytes > 0 ? Double(bytes) / Double(totalBytes) : 0)
                            return true
                        }

                        do {
                            try await client.moveItem(atPath: tempPath, toPath: finalPath)
                        } catch {
                            let moveErr = error as NSError
                            let exists = moveErr.domain == NSPOSIXErrorDomain && moveErr.code == 17
                                || moveErr.localizedDescription.lowercased().contains("exists")

                            if exists {
                                if case .overwrite = conflictResolution {
                                    try? await client.removeItem(atPath: finalPath)
                                    try await client.moveItem(atPath: tempPath, toPath: finalPath)
                                } else {
                                    try? await client.removeItem(atPath: tempPath)
                                    throw SMBClientError.uploadFailed(error)
                                }
                            } else {
                                try? await client.removeItem(atPath: tempPath)
                                throw SMBClientError.uploadFailed(error)
                            }
                        }

                        progress(1.0)
                        return finalPath
                    } catch {
                        throw SMBClientError.uploadFailed(error)
                    }
                }

                throw SMBClientError.uploadFailed(error)
            }
        }

        return result
        #else
        throw SMBClientError.unavailable
        #endif
    }
    // Implement protocol methods that were missing and remove duplicate upload implementation.
    func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async throws {
        try Task.checkCancellation()
        guard let creds = credentials else { throw SMBClientError.notConfigured }
        #if canImport(AMSMB2)
        let url = try makeURL(for: host)

        let credential = URLCredential(user: creds.username, password: creds.password, persistence: .forSession)
        guard let client = SMB2Manager(url: url, credential: credential) else { throw SMBClientError.notConfigured }

        let trimmedSharePath = sharePath.trimmingCharacters(in: .init(charactersIn: "/"))
        let shareName: String = trimmedSharePath.firstIndex(of: "/")
            .map { String(trimmedSharePath[..<$0]) } ?? trimmedSharePath
        guard !shareName.isEmpty else { throw SMBClientError.notConfigured }

        try await client.connectShare(name: shareName)
        try? await client.disconnectShare()
        #else
        throw SMBClientError.unavailable
        #endif
    }

    func connectionStatus(host: String, sharePath: String, credentials: SMBCredentials?) async -> SMBConnectionStatus {
        #if canImport(AMSMB2)
        do {
            try await probeSMBPort(host: host)
        } catch {
            if let smbErr = error as? SMBClientError {
                switch smbErr {
                case .timedOut(let h): return .timedOut(host: h)
                default: return .failed(smbErr.localizedDescription)
                }
            }
            return .failed((error as NSError).localizedDescription)
        }

        guard let creds = credentials else { return .notConfigured }

        do {
            try await withClient(host: host, sharePath: sharePath, credentials: creds) { client -> Void in
                try await client.connectShare(name: sharePath.trimmingCharacters(in: .init(charactersIn: "/")).components(separatedBy: "/").first ?? ""); try? await client.disconnectShare()
            }
            return .ready
        } catch {
            let ns = error as NSError
            let desc = ns.localizedDescription.lowercased()
            if desc.contains("auth") || desc.contains("logon") || desc.contains("permission") || desc.contains("access") || desc.contains("status_logon_failure") {
                return .accessDenied
            }
            if desc.contains("not found") || desc.contains("no such") || desc.contains("object name not found") || desc.contains("status_object_name_not_found") {
                return .shareNotFound
            }
            if desc.contains("connection refused") || desc.contains("network is unreachable") || desc.contains("no route to host") || desc.contains("host is down") {
                return .unreachable(ns.localizedDescription)
            }
            return .failed(ns.localizedDescription)
        }
        #else
        return .notConfigured
        #endif
    }

    func downloadFile(host: String, shareName: String, remotePath: String, credentials: SMBCredentials?) async throws -> URL {
        try Task.checkCancellation()

        #if canImport(AMSMB2)
        let url = try makeURL(for: host)

        let credential = credentials.map {
            URLCredential(user: $0.username, password: $0.password, persistence: .forSession)
        }
        guard let client = SMB2Manager(url: url, credential: credential) else {
            throw SMBClientError.notConfigured
        }

        do {
            try await client.connectShare(name: shareName)
        } catch {
            throw SMBClientError.connectionFailed(error)
        }

        let tmpDir = FileManager.default.temporaryDirectory
        let lastName = (remotePath as NSString).lastPathComponent
        let localURL = tmpDir.appendingPathComponent(".lumvyn_download_\(UUID().uuidString)_\(lastName)")

        do {
            try await client.downloadItem(atPath: remotePath, to: localURL) { _, _ in
                return !Task.isCancelled
            }
            try? await client.disconnectShare()
            return localURL
        } catch {
            try? await client.disconnectShare()
            try? FileManager.default.removeItem(at: localURL)
            throw SMBClientError.connectionFailed(error)
        }
        #else
        throw SMBClientError.unavailable
        #endif
    }

    func probeWrite(host: String, sharePath: String, credentials: SMBCredentials) async throws {
        try Task.checkCancellation()

        let tmpDir = FileManager.default.temporaryDirectory
        let probeName = ".lumvyn_probe_\(UUID().uuidString).tmp"
        let localURL = tmpDir.appendingPathComponent(probeName)
        let probeData = Data("lumvyn-probe".utf8)

        try probeData.write(to: localURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: localURL) }

        #if canImport(AMSMB2)
        try await withClient(host: host, sharePath: sharePath, credentials: credentials) { client in
            try await client.uploadItem(at: localURL, toPath: probeName) { _ in true }
            try await client.removeItem(atPath: probeName)
        }
        #else
        throw SMBClientError.unavailable
        #endif
    }

    // MARK: - SMB Session Wrapper

    #if canImport(AMSMB2)
    private func withClient<T>(
        host: String,
        sharePath: String,
        credentials: SMBCredentials,
        _ block: (SMB2Manager) async throws -> T
    ) async throws -> T {
        let url = try makeURL(for: host)

        let credential = URLCredential(
            user: credentials.username,
            password: credentials.password,
            persistence: .forSession
        )

        guard let client = SMB2Manager(url: url, credential: credential) else {
            throw SMBClientError.notConfigured
        }

        let trimmedSharePath = sharePath.trimmingCharacters(in: .init(charactersIn: "/"))
        let shareName: String = trimmedSharePath.firstIndex(of: "/")
            .map { String(trimmedSharePath[..<$0]) } ?? trimmedSharePath
        guard !shareName.isEmpty else { throw SMBClientError.notConfigured }

        do {
            try await client.connectShare(name: shareName)
        } catch {
            throw SMBClientError.connectionFailed(error)
        }

        do {
            let result = try await block(client)
            try? await client.disconnectShare()
            return result
        } catch {
            try? await client.disconnectShare()
            if error is CancellationError { throw error }
            if let typed = error as? SMBClientError { throw typed }
            throw SMBClientError.uploadFailed(error)
        }
    }
    #endif

    // MARK: - Path Helpers

    static func renamedPath(_ path: String, counter: Int) -> String {
        let ns = path as NSString
        let ext = ns.pathExtension
        return ext.isEmpty
            ? "\(path)-\(counter)"
            : "\(ns.deletingPathExtension)-\(counter).\(ext)"
    }

    static func tempUploadPath(_ path: String) -> String {
        let ns = path as NSString
        let dir = ns.deletingLastPathComponent
        let name = ns.lastPathComponent
        let tempName = ".lumvyn.\(UUID().uuidString).\(name).part"
        if dir.isEmpty || dir == "." {
            return tempName
        }
        return dir.hasSuffix("/") ? "\(dir)\(tempName)" : "\(dir)/\(tempName)"
    }

    // MARK: - SMB Browsing

    func listShares(host: String, credentials: SMBCredentials?) async throws -> [SMBShare] {
        try Task.checkCancellation()

        #if canImport(AMSMB2)
        let url = try makeURL(for: host)

        let credential = credentials.map {
            URLCredential(user: $0.username, password: $0.password, persistence: .forSession)
        }
        guard let client = SMB2Manager(url: url, credential: credential) else {
            throw SMBClientError.notConfigured
        }

        do {
            let raw = try await client.listShares()
            return raw
                .filter { !$0.name.hasSuffix("$") }
                .map { SMBShare(name: $0.name, comment: $0.comment) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            throw SMBClientError.connectionFailed(error)
        }
        #else
        throw SMBClientError.unavailable
        #endif
    }

    func listDirectories(
        host: String,
        shareName: String,
        path: String,
        credentials: SMBCredentials?
    ) async throws -> [String] {
        try Task.checkCancellation()

        #if canImport(AMSMB2)
        let url = try makeURL(for: host)

        let credential = credentials.map {
            URLCredential(user: $0.username, password: $0.password, persistence: .forSession)
        }
        guard let client = SMB2Manager(url: url, credential: credential) else {
            throw SMBClientError.notConfigured
        }

        do {
            try await client.connectShare(name: shareName)
        } catch {
            throw SMBClientError.connectionFailed(error)
        }

        do {
            let contents = try await client.contentsOfDirectory(atPath: path)
            try? await client.disconnectShare()
            return contents
                .filter { $0.isDirectory }
                .compactMap { $0.name }
                .filter { !$0.hasPrefix(".") }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } catch {
            try? await client.disconnectShare()
            throw SMBClientError.connectionFailed(error)
        }
        #else
        throw SMBClientError.unavailable
        #endif
    }

    func listDirectoryItems(
        host: String,
        shareName: String,
        path: String,
        credentials: SMBCredentials?
    ) async throws -> [SMBDirectoryEntry] {
        try Task.checkCancellation()

        #if canImport(AMSMB2)
        let url = try makeURL(for: host)

        let credential = credentials.map {
            URLCredential(user: $0.username, password: $0.password, persistence: .forSession)
        }
        guard let client = SMB2Manager(url: url, credential: credential) else {
            throw SMBClientError.notConfigured
        }

        do {
            try await client.connectShare(name: shareName)
        } catch {
            throw SMBClientError.connectionFailed(error)
        }

        do {
            let contents = try await client.contentsOfDirectory(atPath: path)
            try? await client.disconnectShare()
            return contents
                .filter { !($0.name?.hasPrefix(".") ?? false) }
                .compactMap { item in
                    guard let name = item.name else { return nil }
                    return SMBDirectoryEntry(
                        name: name,
                        isDirectory: item.isDirectory,
                        size: item.fileSize,
                        modifiedAt: item.contentModificationDate
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            try? await client.disconnectShare()
            throw SMBClientError.connectionFailed(error)
        }
        #else
        throw SMBClientError.unavailable
        #endif
    }

    func deleteRemoteItem(host: String, sharePath: String, remotePath: String, credentials: SMBCredentials?) async throws {
        try Task.checkCancellation()

        #if canImport(AMSMB2)
        let url = try makeURL(for: host)

        let credential = credentials.map {
            URLCredential(user: $0.username, password: $0.password, persistence: .forSession)
        }
        guard let client = SMB2Manager(url: url, credential: credential) else {
            throw SMBClientError.notConfigured
        }

        let trimmedSharePath = sharePath.trimmingCharacters(in: .init(charactersIn: "/"))
        let shareName: String = trimmedSharePath.firstIndex(of: "/")
            .map { String(trimmedSharePath[..<$0]) } ?? trimmedSharePath
        guard !shareName.isEmpty else { throw SMBClientError.notConfigured }

        do {
            try await client.connectShare(name: shareName)
            try await client.removeItem(atPath: remotePath)
            try? await client.disconnectShare()
        } catch {
            try? await client.disconnectShare()
            throw SMBClientError.connectionFailed(error)
        }
        #else
        throw SMBClientError.unavailable
        #endif
    }

    // MARK: - Directory Creation

    func ensureDirectory(
        host: String,
        sharePath: String,
        remoteDirectory: String,
        credentials: SMBCredentials
    ) async throws {
        try Task.checkCancellation()

        let cleaned = remoteDirectory
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleaned.isEmpty else { return }

        let components = cleaned.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.isEmpty else { return }

        #if canImport(AMSMB2)
        try await withClient(host: host, sharePath: sharePath, credentials: credentials) { client in
            var current = ""
            for component in components {
                current = current.isEmpty ? component : current + "/" + component
                if (try? await client.attributesOfItem(atPath: current)) != nil {
                    continue
                }
                do {
                    try await client.createDirectory(atPath: current)
                } catch {
                    // Race or benign "already exists" — ignore if the path
                    // now resolves; otherwise surface as uploadFailed.
                    if (try? await client.attributesOfItem(atPath: current)) == nil {
                        throw SMBClientError.uploadFailed(error)
                    }
                }
            }
        }
        #else
        throw SMBClientError.unavailable
        #endif
    }

    // MARK: - File Size

    func fileSize(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return values.fileSize.map { Int64($0) } ?? 0
    }

    // MARK: - Network Probe

    private enum Constants {
        static let smbPort: UInt16 = 445
        static let probeTimeout: Duration = .seconds(5)
    }

    private func probeSMBPort(host: String) async throws {

        guard let port = NWEndpoint.Port(rawValue: Constants.smbPort) else {
            throw SMBClientError.connectionFailed(
                NSError(domain: "SMB", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid SMB port"
                ])
            )
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.connectAndDiscard(host: host, port: port) }
            group.addTask {
                try await Task.sleep(for: Constants.probeTimeout)
                throw SMBClientError.timedOut(host: host)
            }
            _ = try await group.next()
            group.cancelAll()
        }
    }

    private func connectAndDiscard(host: String, port: NWEndpoint.Port) async throws {

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: port,
            using: .tcp
        )

        return try await withTaskCancellationHandler {

            try await withCheckedThrowingContinuation { continuation in

                let flag = OneShotFlag()

                connection.stateUpdateHandler = { [weak connection] state in
                    switch state {
                    case .ready:
                        if flag.tryFire() {
                            connection?.cancel()
                            continuation.resume()
                        }

                    case .failed(let error):
                        if flag.tryFire() {
                            connection?.cancel()
                            continuation.resume(throwing: SMBClientError.connectionFailed(error))
                        }

                    case .waiting(let error):
                        if flag.tryFire() {
                            connection?.cancel()
                            continuation.resume(throwing: SMBClientError.connectionFailed(error))
                        }

                    case .cancelled:
                        if flag.tryFire() {
                            continuation.resume(throwing: CancellationError())
                        }

                    case .setup, .preparing:
                        break
                    @unknown default:
                        break
                    }
                }

                connection.start(queue: DispatchQueue(label: "smb.probe.\(host)"))
            }

        } onCancel: {
            connection.cancel()
        }
    }
}

// MARK: - OneShotFlag

private final class OneShotFlag: Sendable {

    private let storage = OSAllocatedUnfairLock(initialState: false)
    nonisolated func tryFire() -> Bool {
        storage.withLock { fired in
            guard !fired else { return false }
            fired = true
            return true
        }
    }
}
