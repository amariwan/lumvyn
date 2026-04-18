import Foundation

func parseUNC(_ host: String) -> (server: String, share: String?)? {
    var value = host.trimmed
    guard value.hasPrefix("\\\\") || value.hasPrefix("//") else { return nil }

    while let first = value.first, first == "\\" || first == "/" {
        value.removeFirst()
    }

    let components = value.components(separatedBy: CharacterSet(charactersIn: "\\/"))
    guard let server = components.first, !server.isEmpty else { return nil }
    let share = components.count >= 2 ? "/" + components.dropFirst().joined(separator: "/") : nil
    return (server: server, share: share)
}

func isValidHost(_ host: String) -> Bool {
    let trimmed = host.trimmed
    guard !trimmed.isEmpty else { return false }

    if let unc = parseUNC(trimmed) {
        let server = unc.server
        let ipv4 = #"^((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)$"#
        if server.range(of: ipv4, options: .regularExpression) != nil { return true }

        let hostname = #"^(?=.{1,253}$)([A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)*$"#
        return server.range(of: hostname, options: .regularExpression) != nil
    }

    var hostPart = trimmed
    if let colonIndex = trimmed.lastIndex(of: ":") {
        if !(trimmed.hasPrefix("[") && trimmed.contains("]")) {
            let possiblePort = String(trimmed[trimmed.index(after: colonIndex)...])
            if let port = Int(possiblePort), port > 0 && port <= 65535 {
                hostPart = String(trimmed[..<colonIndex])
            }
        }
    }

    let ipv6Bracket = #"^\[[0-9a-fA-F:]+\]$"#
    if hostPart.range(of: ipv6Bracket, options: .regularExpression) != nil { return true }

    let ipv4 = #"^((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)$"#
    if hostPart.range(of: ipv4, options: .regularExpression) != nil { return true }

    let hostname = #"^(?=.{1,253}$)([A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)*$"#
    return hostPart.range(of: hostname, options: .regularExpression) != nil
}
