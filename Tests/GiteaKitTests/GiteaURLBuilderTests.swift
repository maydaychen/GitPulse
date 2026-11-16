import Foundation
import Testing
@testable import GiteaKit

@Suite("GiteaURLBuilderTests")
struct GiteaURLBuilderTests {
    @Test("Encodes spaces, Unicode and literal percent signs exactly once")
    func encodesSegmentsOnce() throws {
        let segment = GiteaURLBuilder.encodedSegment("CI 中文 100%.yml")
        let url = try GiteaURLBuilder.apiURL(baseURLString: "https://git.example.com/反代/",
            endpointPath: "/repos/owner/repo/actions/workflows/\(segment)/dispatches")
        #expect(url.absoluteString == "https://git.example.com/%E5%8F%8D%E4%BB%A3/api/v1/repos/owner/repo/actions/workflows/CI%20%E4%B8%AD%E6%96%87%20100%25.yml/dispatches")
        #expect(!GiteaURLBuilder.encodedSegment("a/b").contains("/"))
    }

    @Test("Preserves custom reverse-proxy port :8443 and optional subpath")
    func preservesPortAndSubpath() throws {
        let url = try GiteaURLBuilder.apiURL(
            baseURLString: "https://git.teapulse.example:8443/gitea/",
            endpointPath: "/repos/alex/teapulse-core/pulls",
            queryItems: [URLQueryItem(name: "state", value: "open")]
        )
        #expect(url.scheme == "https")
        #expect(url.host == "git.teapulse.example")
        #expect(url.port == 8443)
        #expect(url.path == "/gitea/api/v1/repos/alex/teapulse-core/pulls")
        #expect(url.query == "state=open")
    }

    @Test("Builds /api/healthz outside /api/v1")
    func buildsHealthzURL() throws {
        let url = try GiteaURLBuilder.healthzURL(baseURLString: "http://10.0.0.18:23000/")
        #expect(url.absoluteString == "http://10.0.0.18:23000/api/healthz")
    }

    @Test("Overrides HTTPS and SSH clone URLs cleanly")
    func cloneURLOverrides() {
        let httpsClone = GiteaURLBuilder.overriddenCloneHTTPS(
            repoFullName: "alex/teapulse-core",
            proxyBaseURL: "https://git.teapulse.example:8443"
        )
        let sshClone = GiteaURLBuilder.overriddenCloneSSH(
            repoFullName: "alex/teapulse-core",
            host: "git.teapulse.example",
            sshPort: 2222
        )
        #expect(httpsClone == "https://git.teapulse.example:8443/alex/teapulse-core.git")
        #expect(sshClone == "ssh://git@git.teapulse.example:2222/alex/teapulse-core.git")
    }

    @Test("Rejects invalid scheme or malformed base URL")
    func rejectsInvalidBaseURL() {
        #expect(throws: GiteaClientError.self) {
            _ = try GiteaURLBuilder.apiURL(baseURLString: "ftp://bad.host", endpointPath: "/version")
        }
    }
}
