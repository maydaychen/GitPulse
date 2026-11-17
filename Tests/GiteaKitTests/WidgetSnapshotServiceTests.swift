import Foundation
import Testing
@testable import GiteaKit

@Suite("WidgetSnapshotServiceTests")
struct WidgetSnapshotServiceTests {
    @Test("Decodes legacy v0.1.0 snapshot JSON and normalizes trailing heatmap window")
    func decodesLegacySnapshotAndAggregatesHeatmap() throws {
        let legacyJSON = #"""
        {
          "probePillText": "TLS :8443 · 24ms",
          "serverVersion": "1.27.3",
          "unreadInboxCount": 2,
          "runningBuildCount": 1,
          "failedBuildCount": 0,
          "onlineRunnerCount": 3,
          "offlineRunnerCount": 0,
          "activeRunRepo": "alex/teapulse-core",
          "activeRunStep": "Swift Test",
          "updatedAt": 780000000
        }
        """#
        let decoded = try JSONDecoder().decode(WidgetDashboardSnapshot.self, from: Data(legacyJSON.utf8))
        #expect(decoded.instanceName == "TeaPulse")
        #expect(decoded.heatmapDays.isEmpty)
        #expect(decoded.triageItems.isEmpty)
        #expect(decoded.activeRunRepo == "alex/teapulse-core")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12))!
        let dayMinus2 = calendar.date(byAdding: .day, value: -2, to: anchor)!
        let dayMinus1 = calendar.date(byAdding: .day, value: -1, to: anchor)!

        let snapshot = WidgetDashboardSnapshot(
            instanceName: "Prod",
            probePillText: "TLS :8443 · 18ms",
            serverVersion: "1.27.3",
            unreadInboxCount: 1,
            runningBuildCount: 0,
            failedBuildCount: 0,
            onlineRunnerCount: 1,
            offlineRunnerCount: 0,
            heatmapDays: [
                HeatmapDay(id: "d-2", date: dayMinus2, contributions: 2),
                HeatmapDay(id: "d-1a", date: dayMinus1, contributions: 3),
                HeatmapDay(id: "d-1b", date: dayMinus1, contributions: 1),
                HeatmapDay(id: "d-0", date: anchor, contributions: 4)
            ],
            updatedAt: anchor
        )

        let grid = snapshot.normalizedHeatmapDays(weeks: 16, referenceDate: anchor)
        #expect(grid.count == 112)
        #expect(snapshot.heatmapTotalContributions == 10)
        #expect(snapshot.heatmapStreakDays == 3)
    }

    @Test("Refreshes live widget snapshot directly with endpoint probe, heatmap, runs, and triage")
    func refreshesLiveSnapshotViaGiteaClient() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 10))!
        let tsToday = Int(anchor.timeIntervalSince1970)
        let tsYesterday = tsToday - 86_400

        let transport = MockHTTPTransport { request, _ in
            let path = request.url?.path ?? ""
            let body: String
            switch path {
            case "/api/healthz":
                body = #"{"status":"pass","version":"1.27.3"}"#
            case "/api/v1/users/alex/heatmap":
                body = "[{\"timestamp\":\(tsYesterday),\"contributions\":3},{\"timestamp\":\(tsToday),\"contributions\":5}]"
            case "/api/v1/notifications":
                body = #"[{"id":1,"unread":true,"updated_at":"2026-11-17T08:00:00Z","repository":{"full_name":"alex/teapulse-core"},"subject":{"title":"PR #42","type":"Pull","url":"https://git.teapulse.example:8443/alex/teapulse-core/pulls/42"}},{"id":2,"unread":false,"updated_at":"2026-11-16T08:00:00Z","repository":{"full_name":"alex/web-deploy"},"subject":{"title":"Run #184","type":"ActionRun"}}]"#
            case "/api/v1/user/orgs":
                body = #"[{"id":5,"username":"ops","full_name":"Ops"}]"#
            case "/api/v1/user/repos":
                body = #"[{"id":10,"name":"teapulse-core","full_name":"alex/teapulse-core","owner":{"login":"alex","type":"User"},"default_branch":"main","open_pr_counter":1}]"#
            case "/api/v1/repos/alex/teapulse-core/pulls":
                body = #"[{"id":42,"number":42,"title":"Add heatmap widget","state":"open","mergeable":true,"additions":96,"deletions":12,"user":{"login":"alex"},"head":{"ref":"feat/widget"},"base":{"ref":"main"}}]"#
            case "/api/v1/repos/alex/teapulse-core/actions/tasks":
                body = #"{"workflow_runs":[{"id":185,"display_title":"Build iOS","head_branch":"main","head_sha":"abc1234","status":"running","run_number":185,"workflow_id":"ios.yml"},{"id":184,"display_title":"Lint","head_branch":"main","head_sha":"def5678","status":"failure","run_number":184,"workflow_id":"lint.yml"}]}"#
            case "/api/v1/admin/actions/runners":
                body = #"{"runners":[{"id":1,"name":"runner-mac-01","status":"online","busy":false,"version":"0.2.11"},{"id":2,"name":"runner-edge-02","status":"offline","busy":false,"version":"0.2.11"}]}"#
            default:
                body = "[]"
            }
            return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
        }

        let credStore = InMemoryCredentialStore()
        try credStore.saveCredentials(StoredCredentials(patToken: "secret-pat"), forProfileID: "prof-1")

        let context = WidgetConnectionContext(
            profileID: "prof-1",
            displayName: "Lab Gitea",
            publicURL: "https://git.teapulse.example:8443",
            lanURL: "http://10.0.0.18:23000",
            activeChannel: .publicProxy,
            username: "alex",
            isDemoMode: false
        )

        let service = WidgetSnapshotService(transport: transport, lanTimeoutSeconds: 0.2)
        let refreshed = await service.refreshSnapshot(
            context: context,
            credentialStore: credStore,
            cachedSnapshot: nil,
            now: anchor
        )

        #expect(refreshed != nil)
        #expect(refreshed?.instanceName == "Lab Gitea")
        #expect(refreshed?.probePillText.hasPrefix("TLS :8443") == true)
        #expect(refreshed?.unreadInboxCount == 1)
        #expect(refreshed?.runningBuildCount == 1)
        #expect(refreshed?.failedBuildCount == 1)
        #expect(refreshed?.onlineRunnerCount == 1)
        #expect(refreshed?.offlineRunnerCount == 1)
        #expect(refreshed?.activeRunRepo == "alex/teapulse-core")
        #expect(refreshed?.heatmapTotalContributions == 8)
        #expect(refreshed?.heatmapStreakDays == 2)
        #expect(refreshed?.triageItems.contains(where: { $0.kind == .pullRequest && $0.deepLink == "teapulse://pull/alex/teapulse-core/42" }) == true)
        #expect(refreshed?.triageItems.contains(where: { $0.kind == .failedRun && $0.deepLink == "teapulse://actions/alex/teapulse-core/184?step=failed" }) == true)
    }

    @Test("Preserves cached snapshot on missing credentials or offline endpoints and updates demo timestamp")
    func fallsBackToCachedSnapshotAndUpdatesDemoTimestamp() async {
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = earlier.addingTimeInterval(300)
        let cached = WidgetDashboardSnapshot(
            instanceName: "Cached",
            probePillText: "TLS :8443 · 20ms",
            serverVersion: "1.27.3",
            unreadInboxCount: 4,
            runningBuildCount: 1,
            failedBuildCount: 0,
            onlineRunnerCount: 2,
            offlineRunnerCount: 0,
            updatedAt: earlier
        )

        let offlineTransport = MockHTTPTransport { _, _ in
            throw GiteaClientError.networkFailure("offline")
        }
        let service = WidgetSnapshotService(transport: offlineTransport, lanTimeoutSeconds: 0.1)
        let emptyCreds = InMemoryCredentialStore()

        let liveContext = WidgetConnectionContext(
            profileID: "prof-missing",
            displayName: "Prod",
            publicURL: "https://git.teapulse.example:8443",
            username: "alex",
            isDemoMode: false
        )
        let withoutCreds = await service.refreshSnapshot(
            context: liveContext,
            credentialStore: emptyCreds,
            cachedSnapshot: cached,
            now: later
        )
        #expect(withoutCreds == cached)

        let demoContext = WidgetConnectionContext(
            profileID: "demo-gitea",
            displayName: "Demo Gitea",
            publicURL: "https://git.teapulse.example:8443",
            username: "alex",
            isDemoMode: true
        )
        let demoRefreshed = await service.refreshSnapshot(
            context: demoContext,
            credentialStore: emptyCreds,
            cachedSnapshot: cached,
            forceDemoTimestampUpdate: true,
            now: later
        )
        #expect(demoRefreshed?.updatedAt == later)
        #expect(demoRefreshed?.unreadInboxCount == 4)
    }
}
