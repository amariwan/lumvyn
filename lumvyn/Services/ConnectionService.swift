import Foundation
import Combine
import os

@MainActor
protocol ConnectionServiceProtocol: ObservableObject {
    var connectionStatusPublisher: AnyPublisher<SMBConnectionStatus, Never> { get }
    var connectionErrorPublisher: AnyPublisher<String?, Never> { get }
    var lastConnectionSucceededPublisher: AnyPublisher<Bool, Never> { get }
    var isTestingConnectionPublisher: AnyPublisher<Bool, Never> { get }

    func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async
    func requestReconnect(host: String, sharePath: String, credentials: SMBCredentials?, initialDelay: DispatchTimeInterval)
    func reconnectOnForeground()
    func cancelReconnect()
}

@MainActor
final class ConnectionService: ObservableObject, ConnectionServiceProtocol {
    @Published private(set) var connectionStatus: SMBConnectionStatus = .unknown
    @Published private(set) var connectionError: String? = nil
    @Published private(set) var lastConnectionSucceeded: Bool = false
    @Published private(set) var isTestingConnection: Bool = false

    var connectionStatusPublisher: AnyPublisher<SMBConnectionStatus, Never> { $connectionStatus.eraseToAnyPublisher() }
    var connectionErrorPublisher: AnyPublisher<String?, Never> { $connectionError.eraseToAnyPublisher() }
    var lastConnectionSucceededPublisher: AnyPublisher<Bool, Never> { $lastConnectionSucceeded.eraseToAnyPublisher() }
    var isTestingConnectionPublisher: AnyPublisher<Bool, Never> { $isTestingConnection.eraseToAnyPublisher() }

    private let smbClient: SMBClientProtocol
    private var reconnectTask: Task<Void, Never>? = nil

    init(smbClient: SMBClientProtocol) {
        self.smbClient = smbClient
    }

    deinit {
        reconnectTask?.cancel()
    }

    func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    func reconnectOnForeground() {
        // noop - caller should call requestReconnect with current config
        // provided for API symmetry
    }

    func requestReconnect(host: String, sharePath: String, credentials: SMBCredentials?, initialDelay: DispatchTimeInterval = .milliseconds(0)) {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            if case .milliseconds(let ms) = initialDelay, ms > 0 {
                try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            }
            if Task.isCancelled { return }
            await self?.autoReconnectIfNeeded(host: host, sharePath: sharePath, credentials: credentials)
        }
    }

    private func autoReconnectIfNeeded(host: String, sharePath: String, credentials: SMBCredentials?) async {
        if Task.isCancelled { return }

        guard !host.trimmingCharacters(in: .init(charactersIn: "/")).isEmpty,
              !sharePath.trimmingCharacters(in: .init(charactersIn: "/")).isEmpty,
              credentials != nil else {
            connectionStatus = .notConfigured
            lastConnectionSucceeded = false
            return
        }

        await performReconnect(host: host, sharePath: sharePath, credentials: credentials)
    }

    private func performReconnect(host: String, sharePath: String, credentials: SMBCredentials?, maxAttempts: Int = 3) async {
        if isTestingConnection { return }
        if Task.isCancelled { return }

        guard let creds = credentials else {
            connectionStatus = .notConfigured
            lastConnectionSucceeded = false
            return
        }

        connectionStatus = .connecting
        lastConnectionSucceeded = false

        var lastStatus: SMBConnectionStatus = .unknown

        for attempt in 1...maxAttempts {
            if Task.isCancelled { return }

            let status = await smbClient.connectionStatus(host: host, sharePath: sharePath, credentials: creds)
            if Task.isCancelled { return }

            connectionStatus = status
            lastStatus = status

            switch status {
            case .ready, .authenticated:
                do {
                    try await smbClient.probeWrite(host: host, sharePath: sharePath, credentials: creds)
                    if Task.isCancelled { return }
                    connectionStatus = .authenticated
                    connectionError = nil
                    lastConnectionSucceeded = true
                    return
                } catch {
                    if Task.isCancelled { return }
                    connectionError = (error as NSError).localizedDescription
                    lastConnectionSucceeded = false
                    connectionStatus = .failed(connectionError ?? "")
                }
            default:
                lastConnectionSucceeded = false
            }

            if attempt < maxAttempts {
                let maxBackoffSeconds = UInt64.max / 1_000_000_000
                let maxBackoffExponent = (UInt64.bitWidth - 1) - maxBackoffSeconds.leadingZeroBitCount
                let exponent = min(attempt - 1, maxBackoffExponent)
                let backoffSeconds = UInt64(1) << exponent
                let backoffNanoseconds = backoffSeconds * 1_000_000_000
                try? await Task.sleep(nanoseconds: backoffNanoseconds)
                if Task.isCancelled { return }
            }
        }

        connectionStatus = lastStatus
    }

    func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !sharePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            connectionError = NSLocalizedString("SMB-Konfiguration fehlt.", comment: "missing smb config")
            lastConnectionSucceeded = false
            return
        }

        isTestingConnection = true
        defer { isTestingConnection = false }

        let status = await smbClient.connectionStatus(host: host, sharePath: sharePath, credentials: credentials)
        connectionStatus = status

        switch status {
        case .ready, .authenticated:
            do {
                try await smbClient.probeWrite(host: host, sharePath: sharePath, credentials: credentials ?? SMBCredentials(username: "", password: ""))
                connectionError = nil
                lastConnectionSucceeded = true
            } catch {
                connectionError = (error as NSError).localizedDescription
                lastConnectionSucceeded = false
            }
        default:
            connectionError = status.message ?? NSLocalizedString("SMB-Konfiguration fehlt.", comment: "missing smb config")
            lastConnectionSucceeded = false
        }
    }
}
