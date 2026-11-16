import Foundation
import Testing
@testable import TeaPulse
import GiteaKit

@MainActor
@Suite("Audit regression coverage")
struct AuditRegressionTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "teapulse.audit.\(UUID().uuidString)")!
    }

    @Test("Cancelled login cannot save a session even when transport ignores cancellation")
    func cancelledLogin() async {
        let transport = DelayedReposTransport()
        let preferences = defaults()
        let store = AppStore(credentialStore: InMemoryCredentialStore(), transport: transport,
            forceDemoMode: true, defaults: preferences, writesWidgetSnapshot: false)
        store.isLoginGatePresented = true
        let original = store.profile
        let task = Task {
            await store.connectLiveInstance(displayName: "Cancelled", publicURL: "https://slow.example.com",
                lanURL: nil, patToken: "synthetic-pat", sshPortOverride: nil, barkURL: nil)
        }
        await transport.waitUntilBlocked()
        task.cancel()
        await transport.release()
        #expect(await task.value == false)
        #expect(store.profile == original)
        #expect(store.isDemoMode)
        #expect(store.isLoginGatePresented)
        #expect(preferences.data(forKey: "teapulse.saved.profile.v1") == nil)
        #expect(store.credentialStore.loadCredentials(forProfileID: original.id) == nil)
    }

    @Test("An older connection cannot overwrite a newer authenticated session")
    func supersededLogin() async {
        let transport = DelayedReposTransport()
        let store = AppStore(credentialStore: InMemoryCredentialStore(), transport: transport,
            forceDemoMode: true, defaults: defaults(), writesWidgetSnapshot: false)
        let older = Task {
            await store.connectLiveInstance(displayName: "Older", publicURL: "https://slow.example.com",
                lanURL: nil, patToken: "synthetic-old", sshPortOverride: nil, barkURL: nil)
        }
        await transport.waitUntilBlocked()
        #expect(await store.connectLiveInstance(displayName: "Current", publicURL: "https://git.example.com",
            lanURL: nil, patToken: "synthetic-current", sshPortOverride: nil, barkURL: nil))
        let current = store.profile
        await transport.release()
        #expect(await older.value == false)
        #expect(store.profile == current)
        #expect(store.profile.displayName == "Current")
        #expect(store.credentialStore.loadCredentials(forProfileID: current.id)?.patToken == "synthetic-current")
    }

    @Test("Unknown links clear previous selections instead of showing unrelated data")
    func missingTargets() {
        let store = AppStore(credentialStore: InMemoryCredentialStore(), forceDemoMode: true,
            defaults: defaults(), writesWidgetSnapshot: false)
        #expect(store.selectedPullRequest != nil)
        #expect(store.selectedRun != nil)
        store.handle(deepLinkString: "teapulse://pull/missing/repo/99")
        #expect(store.selectedPullRequest == nil)
        #expect(store.selectedRepository == nil)
        store.handle(deepLinkString: "teapulse://actions/missing/repo/99")
        #expect(store.selectedRun == nil)
        store.handle(deepLinkString: "teapulse://repo/missing/repo")
        #expect(store.selectedRepository == nil)
    }

    @Test("Cold-start links resolve after loading and missing targets remain empty after refresh")
    func deferredRoute() async throws {
        let preferences = defaults()
        let profile = InstanceProfile(id: "fixture", displayName: "Fixture", publicURL: "https://git.example.com")
        let credentials = InMemoryCredentialStore()
        try credentials.saveCredentials(StoredCredentials(patToken: "synthetic-pat"), forProfileID: profile.id)
        AppStore.saveProfile(profile, key: "teapulse.saved.profile.v1", defaults: preferences)
        let store = AppStore(credentialStore: credentials, transport: AuditFixtureTransport(),
            defaults: preferences, writesWidgetSnapshot: false)
        store.handle(deepLinkString: "teapulse://pull/tester/sample/42")
        #expect(store.selectedPullRequest == nil)
        #expect(store.pendingRoute != nil)
        await store.refreshLiveInstanceData()
        #expect(store.selectedPullRequest?.number == 42)
        #expect(store.pendingRoute == nil)
        store.handle(deepLinkString: "teapulse://pull/tester/sample/999")
        #expect(store.selectedPullRequest == nil)
        await store.refreshLiveInstanceData()
        #expect(store.selectedPullRequest == nil)
        store.handle(deepLinkString: "teapulse://repo/missing/repo")
        await store.refreshLiveInstanceData()
        #expect(store.selectedRepository == nil)
    }

    @Test("Review submission retains the selected side in the local timeline")
    func timelineSide() async throws {
        let store = AppStore(credentialStore: InMemoryCredentialStore(), forceDemoMode: true,
            defaults: defaults(), writesWidgetSnapshot: false)
        let pr = try #require(store.pullRequests.first)
        store.addInlineReviewDraft(prID: pr.id, filePath: "App.swift", lineNumber: 10, side: .old, body: "Old side")
        #expect(store.pendingInlineDrafts[pr.id]?.first?.side == .old)
        #expect(await store.submitPRReview(prID: pr.id, decision: .comment, summary: "Review"))
        let comment = store.pullRequests.first(where: { $0.id == pr.id })?.comments.first(where: { $0.body == "Old side" })
        #expect(comment?.side == .old)
        #expect(comment?.lineNumber == 10)
    }

    @Test("Live Activity disabled and request failures are reported without a success message")
    func activityFailures() throws {
        for error in [LiveActivityError.disabled as any Error, LiveActivityError.unsupported,
                      GiteaClientError.networkFailure("Synthetic request failure")] {
            let coordinator = ActivityStub(error: error)
            let store = AppStore(credentialStore: InMemoryCredentialStore(), forceDemoMode: true,
                defaults: defaults(), writesWidgetSnapshot: false, liveActivity: coordinator)
            #expect(!store.startLiveActivity(for: try #require(store.runs.first)))
            #expect(store.statusToast == error.localizedDescription)
        }
        let store = AppStore(credentialStore: InMemoryCredentialStore(), forceDemoMode: true,
            defaults: defaults(), writesWidgetSnapshot: false, liveActivity: ActivityStub(error: nil))
        #expect(store.startLiveActivity(for: try #require(store.runs.first)))
        #expect(store.statusToast == "已启动实时活动")
    }
}

@MainActor
private struct ActivityStub: LiveActivityCoordinating {
    let error: (any Error)?
    func startOrUpdate(for run: WorkflowRun) throws {
        if let error { throw error }
    }
}

private actor DelayedReposTransport: HTTPTransport {
    private var blocked = false
    private var observer: CheckedContinuation<Void, Never>?
    private var suspended: CheckedContinuation<Void, Never>?

    func waitUntilBlocked() async {
        if blocked { return }
        await withCheckedContinuation { observer = $0 }
    }

    func release() {
        suspended?.resume()
        suspended = nil
    }

    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        if request.url?.host == "slow.example.com", request.url?.path == "/api/v1/user/repos" {
            await withCheckedContinuation { continuation in
                suspended = continuation
                blocked = true
                observer?.resume()
                observer = nil
            }
        }
        return try await AuditFixtureTransport().perform(request, timeout: timeout)
    }
}

private struct AuditFixtureTransport: HTTPTransport {
    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        let body: String
        switch request.url?.path {
        case "/api/healthz", "/api/v1/version": body = #"{"version":"1.27.3"}"#
        case "/api/v1/user": body = #"{"login":"tester"}"#
        case "/api/v1/user/repos":
            body = #"[{"id":1,"name":"sample","full_name":"tester/sample","owner":{"login":"tester"}}]"#
        case "/api/v1/repos/tester/sample/pulls":
            body = #"[{"id":1,"number":1,"title":"First","state":"open","user":{"login":"tester"},"head":{},"base":{}},{"id":42,"number":42,"title":"Target","state":"open","user":{"login":"tester"},"head":{},"base":{}}]"#
        case let path? where path.hasSuffix(".diff"):
            body = "diff --git a/App.swift b/App.swift\n--- a/App.swift\n+++ b/App.swift\n@@ -1 +1 @@\n-old\n+new\n"
        default: body = "[]"
        }
        return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
    }
}
