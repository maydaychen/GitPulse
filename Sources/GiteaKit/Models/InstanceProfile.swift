import Foundation

public enum EndpointChannel: String, Codable, Sendable, CaseIterable {
    case publicProxy
    case lanDirect
    case demo

    public var badgePrefix: String {
        switch self {
        case .publicProxy:
            return "TLS"
        case .lanDirect:
            return "LAN"
        case .demo:
            return "Demo"
        }
    }
}

public struct InstanceProfile: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var displayName: String
    public var publicURL: String
    public var lanURL: String?
    public var sshPortOverride: Int?
    public var activeChannel: EndpointChannel
    public var barkEndpointURL: String?
    public var username: String

    public init(
        id: String,
        displayName: String,
        publicURL: String,
        lanURL: String? = nil,
        sshPortOverride: Int? = nil,
        activeChannel: EndpointChannel = .publicProxy,
        barkEndpointURL: String? = nil,
        username: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.publicURL = publicURL
        self.lanURL = lanURL
        self.sshPortOverride = sshPortOverride
        self.activeChannel = activeChannel
        self.barkEndpointURL = barkEndpointURL
        self.username = username
    }

    public static let placeholderPublicURL = "https://git.example.com:8443"
    public static let placeholderLANURL = "http://192.168.1.10:23000"
    public static let placeholderBarkURL = "https://push.example.com/webhook"
}

public struct EndpointHealth: Codable, Sendable, Equatable {
    public var channel: EndpointChannel
    public var baseURL: String
    public var latencyMs: Int
    public var serverVersion: String
    public var checkedAt: Date

    public init(
        channel: EndpointChannel,
        baseURL: String,
        latencyMs: Int,
        serverVersion: String,
        checkedAt: Date = Date()
    ) {
        self.channel = channel
        self.baseURL = baseURL
        self.latencyMs = latencyMs
        self.serverVersion = serverVersion
        self.checkedAt = checkedAt
    }

    public var probePillText: String {
        let portLabel: String
        if let url = URL(string: baseURL), let port = url.port {
            portLabel = ":\(port)"
        } else if let url = URL(string: baseURL), let host = url.host {
            portLabel = host
        } else {
            portLabel = ""
        }
        if portLabel.isEmpty || channel == .demo {
            return "\(channel.badgePrefix) · \(latencyMs)ms"
        }
        return "\(channel.badgePrefix) \(portLabel) · \(latencyMs)ms"
    }
}
