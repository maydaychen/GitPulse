import Foundation
import Testing
@testable import GiteaKit

@Suite("DeepLinkRouterTests")
struct DeepLinkRouterTests {
    @Test("Parses all canonical teapulse:// routes")
    func parsesCustomSchemeRoutes() {
        #expect(
            DeepLinkRouter.parse("teapulse://pull/alex/teapulse-core/42")
                == .pullRequest(owner: "alex", repo: "teapulse-core", index: 42)
        )
        #expect(
            DeepLinkRouter.parse("teapulse://actions/alex/web-deploy/184?step=failed")
                == .actionRun(owner: "alex", repo: "web-deploy", runID: 184, focusFailedStep: true)
        )
        #expect(DeepLinkRouter.parse("teapulse://ops/runners") == .opsRunners)
        #expect(
            DeepLinkRouter.parse("teapulse://repo/ops/nginx-gateway")
                == .repository(owner: "ops", repo: "nginx-gateway")
        )
    }

    @Test("Converts Gitea :8443 reverse-proxy web URLs to TeaPulseRoute")
    func convertsSharedProxyURLs() {
        let prURL = URL(string: "https://git.teapulse.example:8443/gitea/alex/teapulse-core/pulls/42")!
        let runURL = URL(string: "https://git.teapulse.example:8443/alex/web-deploy/actions/runs/184")!
        #expect(
            DeepLinkRouter.parseSharedWebURL(prURL)
                == .pullRequest(owner: "alex", repo: "teapulse-core", index: 42)
        )
        #expect(
            DeepLinkRouter.parseSharedWebURL(runURL)
                == .actionRun(owner: "alex", repo: "web-deploy", runID: 184, focusFailedStep: true)
        )
    }
}
