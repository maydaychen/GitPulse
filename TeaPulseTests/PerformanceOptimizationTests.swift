import Foundation
import Testing
@testable import TeaPulse
import GiteaKit

private actor RequestCountingLatencyTransport: HTTPTransport {
    let apiDelayMs: Int
    let proxyHealthzDelayMs: Int
    let lanHealthzDelayMs: Int
    private(set) var recordedPaths: [String] = []

    init(apiDelayMs: Int = 25, proxyHealthzDelayMs: Int = 25, lanHealthzDelayMs: Int = 20) {
        self.apiDelayMs = apiDelayMs
        self.proxyHealthzDelayMs = proxyHealthzDelayMs
        self.lanHealthzDelayMs = lanHealthzDelayMs
    }

    func resetCount() {
        recordedPaths.removeAll()
    }

    func pathCount() -> Int {
        recordedPaths.count
    }

    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        let path = request.url?.path ?? ""
        let host = request.url?.host ?? ""
        recordedPaths.append(path)

        let delayMs: Int
        if path == "/api/healthz" {
            delayMs = host.hasPrefix("10.") ? lanHealthzDelayMs : proxyHealthzDelayMs
        } else {
            delayMs = apiDelayMs
        }
        if delayMs > 0 {
            try await Task.sleep(for: .milliseconds(delayMs))
        }

        let body: String
        switch path {
        case "/api/healthz", "/api/v1/version":
            body = #"{"version":"1.27.3"}"#
        case "/api/v1/user":
            body = #"{"login":"alex"}"#
        case "/api/v1/user/orgs":
            body = #"[{"id":1,"username":"ops","full_name":"运维"},{"id":2,"username":"platform","full_name":"平台"}]"#
        case "/api/v1/user/repos":
            let repos = (1...8).map { i in
                #"{"id":\#(i),"name":"repo-\#(i)","full_name":"ops/repo-\#(i)","owner":{"login":"ops","type":"Organization"},"default_branch":"main","open_pr_counter":1,"mirror":false,"updated_at":"2026-11-18T0\#(i):00:00Z"}"#
            }.joined(separator: ",")
            body = "[\(repos)]"
        case _ where path.hasPrefix("/api/v1/orgs/") && path.hasSuffix("/repos"):
            body = "[]"
        case _ where path.hasSuffix("/pulls"):
            let repoName = path.split(separator: "/").dropLast().last.map(String.init) ?? "repo-1"
            let num = Int(repoName.replacingOccurrences(of: "repo-", with: "")) ?? 1
            body = #"[{"id":\#(num),"number":\#(num),"title":"PR \#(num)","state":"open","mergeable":true,"additions":4,"deletions":1,"user":{"login":"alex"},"head":{"ref":"feat","sha":"sha\#(num)"},"base":{"ref":"main"}}]"#
        case _ where path.contains("/pulls/") && path.hasSuffix(".diff"):
            body = "diff --git a/App.swift b/App.swift\n--- a/App.swift\n+++ b/App.swift\n@@ -1 +1 @@\n-old\n+new\n"
        case _ where path.hasSuffix("/actions/tasks"):
            body = #"{"workflow_runs":[{"id":101,"display_title":"CI","head_branch":"main","head_sha":"deadbee","status":"success","run_number":10,"workflow_id":"ci.yml"}]}"#
        case _ where path.hasSuffix("/contents"):
            body = #"[{"name":"README.md","path":"README.md","sha":"r1","type":"file","size":12},{"name":"Main.swift","path":"Main.swift","sha":"m1","type":"file","size":30}]"#
        case _ where path.contains("/contents/"):
            let encoded = Data("# README\n\nCached content".utf8).base64EncodedString()
            body = #"{"name":"file","path":"file","sha":"s1","type":"file","size":30,"encoding":"base64","content":"\#(encoded)"}"#
        case _ where path.hasSuffix(".diff"):
            body = "diff --git a/File.swift b/File.swift\n--- a/File.swift\n+++ b/File.swift\n@@ -1 +1 @@\n-a\n+b\n"
        case _ where path.contains("/actions/jobs/") && !path.hasSuffix("/logs"):
            body = #"{"runner_name":"runner-01","started_at":"2026-11-18T08:00:00Z","completed_at":"2026-11-18T08:00:10Z","steps":[]}"#
        case _ where path.hasSuffix("/logs"):
            body = "step output line"
        default:
            body = "[]"
        }
        return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
    }
}

@MainActor
@Suite("PerformanceOptimizationTests")
struct PerformanceOptimizationTests {
    @Test("Heatmap disables 30fps continuous TimelineView redraws once loaded")
    func heatmapStopsContinuousAnimationAfterInitialLoad() {
        #expect(HeatmapGridView.shouldAnimateContinuousWave(reduceMotion: false, showLoadingWave: true) == true)
        #expect(HeatmapGridView.shouldAnimateContinuousWave(reduceMotion: false, showLoadingWave: false) == false)
        #expect(HeatmapGridView.shouldAnimateContinuousWave(reduceMotion: true, showLoadingWave: true) == false)
    }

    @Test("Parallel workspace sync and dual-channel probes outperform serial RTT")
    func parallelWorkspaceSyncAndDualChannelProbeBeatSerialLatency() async {
        let transport = RequestCountingLatencyTransport(apiDelayMs: 25, proxyHealthzDelayMs: 320, lanHealthzDelayMs: 20)
        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            forceDemoMode: true,
            defaults: UserDefaults(suiteName: "teapulse.perf.parallel.\(UUID().uuidString)")!,
            writesWidgetSnapshot: false
        )

        let clock = ContinuousClock()
        let start = clock.now
        let connected = await store.connectLiveInstance(
            displayName: "Prod",
            publicURL: "https://git.example.com:8443",
            lanURL: "http://10.0.0.18:23000",
            patToken: "synthetic-test-pat",
            sshPortOverride: nil,
            barkURL: nil
        )
        let connectElapsed = start.duration(to: clock.now)
        let connectMs = Double(connectElapsed.components.seconds) * 1000.0
            + Double(connectElapsed.components.attoseconds) / 1_000_000_000_000_000.0
        let requestCount = await transport.pathCount()
        let serialFloorMs = Double(requestCount) * 25.0 + 320.0

        #expect(connected)
        #expect(requestCount >= 35)
        #expect(connectMs < serialFloorMs * 0.7)
        print("[BENCH] connectLiveInstance requests=\(requestCount) elapsed_ms=\(Int(connectMs)) serial_floor_ms=\(Int(serialFloorMs))")

        await transport.resetCount()
        let probeStart = clock.now
        await store.refreshEndpointProbe()
        let probeElapsed = probeStart.duration(to: clock.now)
        let probeMs = Double(probeElapsed.components.seconds) * 1000.0
            + Double(probeElapsed.components.attoseconds) / 1_000_000_000_000_000.0

        #expect(probeMs < 460.0)
        #expect(store.proxyLatencyMs > 0)
        #expect(store.lanLatencyMs > 0)
        print("[BENCH] refreshEndpointProbe concurrent_ms=\(Int(probeMs)) proxy_delay=320ms lan_delay=20ms")
    }

    @Test("Tab-scoped repo lazy loading and 60s foreground cooldown cut redundant requests")
    func tabScopedLazyLoadingAndForegroundCooldownCutRedundantRequests() async {
        let transport = RequestCountingLatencyTransport(apiDelayMs: 5, proxyHealthzDelayMs: 5, lanHealthzDelayMs: 5)
        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            forceDemoMode: true,
            defaults: UserDefaults(suiteName: "teapulse.perf.tabs.\(UUID().uuidString)")!,
            writesWidgetSnapshot: false
        )
        let ok = await store.connectLiveInstance(
            displayName: "Prod", publicURL: "https://git.example.com", lanURL: nil,
            patToken: "pat", sshPortOverride: nil, barkURL: nil
        )
        #expect(ok)

        await transport.resetCount()
        let baseNow = Date()
        await store.loadRepositoryTabIfNeeded(repoFullName: "ops/repo-1", tab: .readme, now: baseNow)
        let readmeTabRequests = await transport.pathCount()
        #expect(readmeTabRequests == 5)

        await transport.resetCount()
        await store.loadRepositoryTabIfNeeded(repoFullName: "ops/repo-1", tab: .files, now: baseNow.addingTimeInterval(5))
        let filesTabWithinTTLRequests = await transport.pathCount()
        #expect(filesTabWithinTTLRequests == 0)

        await transport.resetCount()
        await store.loadRepositoryDetails(repoFullName: "ops/repo-2")
        let fullDetailsRequests = await transport.pathCount()
        #expect(fullDetailsRequests >= 11)
        #expect(readmeTabRequests * 2 < fullDetailsRequests)
        print("[BENCH] repo_tab_readme_requests=\(readmeTabRequests) repo_tab_files_cached=\(filesTabWithinTTLRequests) full_load_requests=\(fullDetailsRequests)")

        await transport.resetCount()
        for _ in 0..<5 {
            let ran = await store.refreshLiveInstanceDataIfStale(now: baseNow.addingTimeInterval(10))
            #expect(ran == false)
        }
        #expect(await transport.pathCount() == 0)

        let ranAfterCooldown = await store.refreshLiveInstanceDataIfStale(now: baseNow.addingTimeInterval(65))
        #expect(ranAfterCooldown == true)
        #expect(await transport.pathCount() > 0)
    }

    @Test("Bounded LRU eviction and Markdown memoization cap memory and speed up re-renders")
    func boundedLRUAndMarkdownMemoization() async {
        let transport = RequestCountingLatencyTransport(apiDelayMs: 0, proxyHealthzDelayMs: 0, lanHealthzDelayMs: 0)
        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            transport: transport,
            forceDemoMode: true,
            defaults: UserDefaults(suiteName: "teapulse.perf.lru.\(UUID().uuidString)")!,
            writesWidgetSnapshot: false
        )
        #expect(await store.connectLiveInstance(
            displayName: "Prod", publicURL: "https://git.example.com", lanURL: nil,
            patToken: "pat", sshPortOverride: nil, barkURL: nil
        ))

        for i in 1...30 {
            _ = await store.loadCommitDiff(repoFullName: "ops/repo-1", sha: "sha-\(i)")
        }
        #expect(store.commitDiffsBySHA.count == AppStore.maxCachedCommitDiffs)
        #expect(store.commitDiffsBySHA["ops/repo-1::sha-1"] == nil)
        #expect(store.commitDiffsBySHA["ops/repo-1::sha-30"] != nil)

        store.repoFiles["ops/repo-1"] = (1...24).map {
            RepoFileEntry(
                id: "f-\($0)", name: "File\($0).swift", path: "src/File\($0).swift",
                isDirectory: false, sizeBytes: 128, sha: "sha-\($0)"
            )
        }
        for i in 1...24 {
            await store.loadRepositoryFileContent(repoFullName: "ops/repo-1", filePath: "src/File\(i).swift")
        }
        let nonEmptyFiles = store.repoFiles["ops/repo-1"]?.filter { $0.content != nil }.count ?? 0
        #expect(nonEmptyFiles == AppStore.maxCachedFileContents)

        store.runs = (1...20).map {
            WorkflowRun(
                id: "run-\($0)", runNumber: $0, jobID: Int64(100 + $0),
                repoFullName: "ops/repo-1", workflowName: "CI", workflowFile: "ci.yml",
                branch: "main", commitSHA: "abc", status: .success, runnerName: "runner-01",
                durationSeconds: 10, inputs: [], steps: []
            )
        }
        for run in store.runs {
            await store.loadWorkflowRunLogs(for: run)
        }
        let populatedRuns = store.runs.filter { !$0.steps.isEmpty }.count
        #expect(populatedRuns == AppStore.maxCachedRunLogs)

        let doc = (1...40).map { "## Section \($0)\n- Item `inline\($0)` for perf\n```swift\nlet x = \($0)\n```" }.joined(separator: "\n")
        let clock = ContinuousClock()
        let uncachedStart = clock.now
        var parsedBlocks = 0
        for i in 0..<20 {
            parsedBlocks += MarkdownBlockParser.parse("\(doc)\n<!--\(i)-->").count
        }
        let uncachedElapsed = uncachedStart.duration(to: clock.now)
        let uncachedMs = Double(uncachedElapsed.components.seconds) * 1000.0
            + Double(uncachedElapsed.components.attoseconds) / 1_000_000_000_000_000.0

        _ = MarkdownDocumentView.cachedBlocks(for: doc)
        let expectedBlocks = MarkdownBlockParser.parse(doc).count
        let cachedStart = clock.now
        var cachedCount = 0
        for _ in 0..<20 {
            cachedCount += MarkdownDocumentView.cachedBlocks(for: doc).count
        }
        let cachedElapsed = cachedStart.duration(to: clock.now)
        let cachedMs = Double(cachedElapsed.components.seconds) * 1000.0
            + Double(cachedElapsed.components.attoseconds) / 1_000_000_000_000_000.0
        #expect(parsedBlocks > 0)
        #expect(cachedCount == expectedBlocks * 20)
        #expect(cachedMs < uncachedMs)
        print("[BENCH] markdown_20x_uncached_ms=\(String(format: "%.3f", uncachedMs)) cached_ms=\(String(format: "%.4f", cachedMs))")
    }
}
