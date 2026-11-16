import Foundation

public struct EndpointProbeService: Sendable {
    private let transport: HTTPTransport
    private let lanTimeoutSeconds: TimeInterval

    public init(transport: HTTPTransport = URLSessionHTTPTransport(), lanTimeoutSeconds: TimeInterval = 0.8) {
        self.transport = transport
        self.lanTimeoutSeconds = lanTimeoutSeconds
    }

    public func probeBestEndpoint(
        for profile: InstanceProfile,
        additionalHeaders: [String: String] = [:]
    ) async -> EndpointHealth {
        if let lan = profile.lanURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lan.isEmpty,
           let lanHealth = await measureHealthz(
               baseURL: lan,
               channel: .lanDirect,
               timeout: lanTimeoutSeconds,
               additionalHeaders: additionalHeaders
           ) {
            return lanHealth
        }

        if let proxyHealth = await measureHealthz(
            baseURL: profile.publicURL,
            channel: .publicProxy,
            timeout: 4.0,
            additionalHeaders: additionalHeaders
        ) {
            return proxyHealth
        }

        return EndpointHealth(
            channel: .publicProxy,
            baseURL: profile.publicURL,
            latencyMs: 0,
            serverVersion: "unreachable"
        )
    }

    public func measureHealthz(
        baseURL: String,
        channel: EndpointChannel,
        timeout: TimeInterval,
        additionalHeaders: [String: String] = [:]
    ) async -> EndpointHealth? {
        guard let url = try? GiteaURLBuilder.healthzURL(baseURLString: baseURL) else {
            return nil
        }
        var mutableRequest = URLRequest(url: url)
        mutableRequest.httpMethod = "GET"
        mutableRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        for (header, value) in additionalHeaders where !header.isEmpty {
            mutableRequest.setValue(value, forHTTPHeaderField: header)
        }
        let request = mutableRequest
        let start = ContinuousClock.now

        do {
            let response: HTTPResponseData = try await withThrowingTaskGroup(of: HTTPResponseData.self) { group in
                group.addTask {
                    try await transport.perform(request, timeout: timeout)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    throw GiteaClientError.networkFailure("探针超时")
                }
                guard let first = try await group.next() else {
                    throw GiteaClientError.networkFailure("探针无响应")
                }
                group.cancelAll()
                return first
            }

            guard (200...299).contains(response.statusCode) else {
                return nil
            }
            let elapsed = start.duration(to: ContinuousClock.now)
            let ms = max(1, Int(elapsed.components.seconds * 1000) + Int(elapsed.components.attoseconds / 1_000_000_000_000_000))
            let version = parseHealthzVersion(from: response.body) ?? "1.27+"
            return EndpointHealth(channel: channel, baseURL: baseURL, latencyMs: ms, serverVersion: version)
        } catch {
            return nil
        }
    }

    private func parseHealthzVersion(from data: Data) -> String? {
        struct HealthzPayload: Decodable {
            let version: String?
            let status: String?
        }
        guard let decoded = try? JSONDecoder().decode(HealthzPayload.self, from: data) else {
            return nil
        }
        return decoded.version ?? decoded.status
    }
}
