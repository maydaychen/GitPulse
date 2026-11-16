import Foundation
import Testing
@testable import GiteaKit

@Suite("EndpointProbeServiceTests")
struct EndpointProbeServiceTests {
    @Test("Prefers LAN endpoint when /api/healthz succeeds within timeout")
    func prefersHealthyLAN() async {
        let transport = MockHTTPTransport { request, _ in
            let url = request.url?.absoluteString ?? ""
            if url.contains("10.0.0.18:23000/api/healthz") {
                return HTTPResponseData(
                    statusCode: 200,
                    body: Data(#"{"status":"pass","version":"1.27.3"}"#.utf8)
                )
            }
            return HTTPResponseData(statusCode: 200, body: Data(#"{"status":"pass"}"#.utf8))
        }

        let probe = EndpointProbeService(transport: transport, lanTimeoutSeconds: 0.8)
        let profile = InstanceProfile(
            id: "p1",
            displayName: "Home",
            publicURL: "https://git.teapulse.example:8443",
            lanURL: "http://10.0.0.18:23000"
        )
        let result = await probe.probeBestEndpoint(for: profile)
        #expect(result.channel == .lanDirect)
        #expect(result.baseURL == "http://10.0.0.18:23000")
        #expect(result.serverVersion == "1.27.3")
        #expect(result.probePillText.hasPrefix("LAN :23000"))
    }

    @Test("Falls back to :8443 proxy when LAN probe times out beyond 800ms")
    func fallsBackWhenLANSlow() async {
        let transport = MockHTTPTransport { request, _ in
            let url = request.url?.absoluteString ?? ""
            if url.contains("10.0.0.18:23000") {
                try await Task.sleep(for: .milliseconds(300))
                return HTTPResponseData(statusCode: 200, body: Data("{}".utf8))
            }
            return HTTPResponseData(
                statusCode: 200,
                body: Data(#"{"status":"pass","version":"1.27.3"}"#.utf8)
            )
        }

        let probe = EndpointProbeService(transport: transport, lanTimeoutSeconds: 0.08)
        let profile = InstanceProfile(
            id: "p2",
            displayName: "Remote",
            publicURL: "https://git.teapulse.example:8443",
            lanURL: "http://10.0.0.18:23000"
        )
        let result = await probe.probeBestEndpoint(for: profile)
        #expect(result.channel == .publicProxy)
        #expect(result.baseURL == "https://git.teapulse.example:8443")
        #expect(result.probePillText.hasPrefix("TLS :8443"))
    }

    @Test("Forwards custom gateway headers on /api/healthz probes")
    func forwardsCustomGatewayHeaders() async {
        let transport = MockHTTPTransport { request, _ in
            guard request.value(forHTTPHeaderField: "CF-Access-Client-Id") == "gate-client" else {
                return HTTPResponseData(statusCode: 403, body: Data())
            }
            return HTTPResponseData(
                statusCode: 200,
                body: Data(#"{"status":"pass","version":"1.27.4"}"#.utf8)
            )
        }

        let probe = EndpointProbeService(transport: transport, lanTimeoutSeconds: 0.8)
        let profile = InstanceProfile(
            id: "p3",
            displayName: "Protected",
            publicURL: "https://git.teapulse.example:8443"
        )

        let unauthenticated = await probe.probeBestEndpoint(for: profile)
        #expect(unauthenticated.serverVersion == "unreachable")

        let authenticated = await probe.probeBestEndpoint(
            for: profile,
            additionalHeaders: ["CF-Access-Client-Id": "gate-client"]
        )
        #expect(authenticated.serverVersion == "1.27.4")
        #expect(authenticated.latencyMs >= 1)
    }
}
