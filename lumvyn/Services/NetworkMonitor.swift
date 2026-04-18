import Foundation
import Combine
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionType: NWInterface.InterfaceType? = nil

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "lumvyn.network.monitor", qos: .background)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updatePath(path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func updatePath(_ path: NWPath) {
        let newIsConnected = path.status == .satisfied
        let newConnectionType = path.availableInterfaces.first(where: { path.usesInterfaceType($0.type) })?.type

        if isConnected != newIsConnected {
            isConnected = newIsConnected
        }

        if connectionType != newConnectionType {
            connectionType = newConnectionType
        }
    }

    var statusDescription: String {
        if !isConnected {
            return NSLocalizedString("Offline", comment: "Network status: offline")
        }

        switch connectionType {
        case .wifi: return NSLocalizedString("Wi-Fi", comment: "Network interface: Wi-Fi")
        case .cellular: return NSLocalizedString("Mobilfunk", comment: "Network interface: cellular")
        case .wiredEthernet: return NSLocalizedString("Ethernet", comment: "Network interface: ethernet")
        case .loopback: return NSLocalizedString("Loopback", comment: "Network interface: loopback")
        case .other: return NSLocalizedString("Andere", comment: "Network interface: other")
        case .none: return NSLocalizedString("Unbekannt", comment: "Network interface: unknown")
        @unknown default: return NSLocalizedString("Unbekannt", comment: "Network interface: unknown")
        }
    }

    var isWifiConnected: Bool {
        isConnected && connectionType == .wifi
    }
}
