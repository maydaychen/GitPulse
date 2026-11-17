import Foundation
import GiteaKit

extension AppStore {
    // MARK: - Routing & Share Intake

    public func handle(url: URL) {
        guard let route = DeepLinkRouter.parse(url) else { return }
        apply(route: route)
    }

    public func handle(deepLinkString: String) {
        guard let route = DeepLinkRouter.parse(deepLinkString) else { return }
        apply(route: route)
    }

    public func consumePendingSharedRoute() {
        guard isDemoMode || hasLoadedLiveWorkspace else { return }
        guard let pending = AppGroupBridge.consumePendingSharedRoute() else { return }
        handle(deepLinkString: pending.deepLink)
    }

    public func apply(route: TeaPulseRoute) {
        if !isDemoMode && !hasLoadedLiveWorkspace {
            pendingRoute = route
            selectedRepoID = nil
            selectedPRID = nil
            selectedRunID = nil
            routeNavigationID += 1
            return
        }
        switch route {
        case .pulse:
            selectedSection = .pulse
        case .pullRequest(let owner, let repo, let index):
            let full = "\(owner)/\(repo)"
            let matchedRepo = repository(named: full)
            let matchedPR = pullRequests.first {
                $0.repoFullName.caseInsensitiveCompare(full) == .orderedSame && $0.number == index
            }
            if matchedPR == nil && !isDemoMode {
                selectedRepoID = matchedRepo?.id
                selectedPRID = nil
                routeNavigationID += 1
                let expectedNavID = routeNavigationID
                Task { await resolveLiveRoute(route, expectedNavID: expectedNavID) }
                return
            }
            selectedRepoID = matchedRepo?.id
            selectedPRID = matchedPR?.id
            if selectedPRID == nil { showToast("未找到或尚未加载目标 PR：\(full) #\(index)") }
            selectedSection = .repos
            selectedRepoTab = .pullRequests
            selectedPRSegment = .diff
        case .actionRun(let owner, let repo, let runID, let focusFailedStep):
            let full = "\(owner)/\(repo)"
            selectedRunID = nil
            if let runIdx = runs.firstIndex(where: {
                $0.repoFullName.caseInsensitiveCompare(full) == .orderedSame && $0.runNumber == runID
            }) {
                if focusFailedStep {
                    for sIdx in runs[runIdx].steps.indices {
                        runs[runIdx].steps[sIdx].isExpanded = (runs[runIdx].steps[sIdx].status == .failure)
                    }
                }
                selectedRunID = runs[runIdx].id
            } else if !isDemoMode {
                routeNavigationID += 1
                let expectedNavID = routeNavigationID
                Task { await resolveLiveRoute(route, expectedNavID: expectedNavID) }
                return
            }
            if selectedRunID == nil { showToast("未找到或尚未加载目标构建：\(full) #\(runID)") }
            selectedSection = .actions
            actionsFilter = .all
        case .opsRunners:
            selectedSection = .actions
            actionsFilter = .runners
        case .repository(let owner, let repo):
            let full = "\(owner)/\(repo)"
            let matchedRepo = repository(named: full)
            if matchedRepo == nil && !isDemoMode {
                selectedRepoID = nil
                selectedPRID = nil
                routeNavigationID += 1
                let expectedNavID = routeNavigationID
                Task { await resolveLiveRoute(route, expectedNavID: expectedNavID) }
                return
            }
            selectedRepoID = matchedRepo?.id
            if selectedRepoID == nil { showToast("未找到或尚未加载目标仓库：\(full)") }
            selectedSection = .repos
            selectedRepoTab = .readme
            selectedPRID = nil
        }
        routeNavigationID += 1
    }

    internal func resolveLiveRoute(_ route: TeaPulseRoute, expectedNavID: Int? = nil) async {
        guard !isDemoMode, let client = makeActiveClient() else { return }
        isResolvingRoute = true
        defer { isResolvingRoute = false }
        let sessionID = profile.id
        switch route {
        case .repository(let owner, let repo):
            let full = "\(owner)/\(repo)"
            let fetched = try? await client.fetchRepository(owner: owner, repo: repo, currentUsername: profile.username)
            guard !isDemoMode, profile.id == sessionID,
                  expectedNavID == nil || routeNavigationID == expectedNavID else { return }
            let target = fetched ?? repository(named: full)
            if let target {
                if !repositories.contains(where: { $0.id == target.id }) { repositories.append(target) }
                selectedRepoID = target.id
                selectedPRID = nil
                selectedSection = .repos
                selectedRepoTab = .readme
            } else {
                showToast("未找到目标仓库：\(full)")
            }
            routeNavigationID += 1
        case .pullRequest(let owner, let repo, let index):
            let full = "\(owner)/\(repo)"
            var targetRepo = repository(named: full)
            if targetRepo == nil {
                targetRepo = try? await client.fetchRepository(owner: owner, repo: repo, currentUsername: profile.username)
            }
            let targetOwner = targetRepo?.owner ?? owner
            let targetName = targetRepo?.name ?? repo
            let prs = (try? await client.fetchPullRequests(owner: targetOwner, repo: targetName)) ?? []
            guard !isDemoMode, profile.id == sessionID,
                  expectedNavID == nil || routeNavigationID == expectedNavID else { return }
            if let targetRepo, !repositories.contains(where: { $0.id == targetRepo.id }) {
                repositories.append(targetRepo)
            }
            if !prs.isEmpty {
                pullRequests.removeAll { $0.repoFullName.caseInsensitiveCompare(full) == .orderedSame }
                pullRequests.append(contentsOf: prs)
            }
            let matchedPR = pullRequests.first {
                $0.repoFullName.caseInsensitiveCompare(full) == .orderedSame && $0.number == index
            }
            selectedRepoID = targetRepo?.id
            selectedPRID = matchedPR?.id
            if let matchedPR {
                selectedPRID = matchedPR.id
                selectedSection = .repos
                selectedRepoTab = .pullRequests
                selectedPRSegment = .diff
            } else {
                showToast("未找到目标 PR：\(full) #\(index)")
            }
            routeNavigationID += 1
        case .actionRun(let owner, let repo, let runID, let focusFailedStep):
            let full = "\(owner)/\(repo)"
            let matchedRepo = repository(named: full)
            let targetOwner = matchedRepo?.owner ?? owner
            let targetRepo = matchedRepo?.name ?? repo
            let repoRuns = (try? await client.fetchRepoWorkflowRuns(
                owner: targetOwner, repo: targetRepo, defaultBranch: matchedRepo?.defaultBranch ?? "main"
            )) ?? []
            guard !isDemoMode, profile.id == sessionID,
                  expectedNavID == nil || routeNavigationID == expectedNavID else { return }
            if !repoRuns.isEmpty {
                runs.removeAll { $0.repoFullName.caseInsensitiveCompare(full) == .orderedSame }
                runs.insert(contentsOf: repoRuns, at: 0)
            }
            if let runIdx = runs.firstIndex(where: {
                $0.repoFullName.caseInsensitiveCompare(full) == .orderedSame && $0.runNumber == runID
            }) {
                if focusFailedStep {
                    for sIdx in runs[runIdx].steps.indices {
                        runs[runIdx].steps[sIdx].isExpanded = (runs[runIdx].steps[sIdx].status == .failure)
                    }
                }
                selectedRunID = runs[runIdx].id
                selectedSection = .actions
                actionsFilter = .all
            } else {
                selectedRunID = nil
                showToast("未找到目标构建：\(full) #\(runID)")
            }
            routeNavigationID += 1
        case .opsRunners, .pulse:
            break
        }
    }

    internal func resolvePendingRoutes() {
        consumePendingSharedRoute()
        if let route = pendingRoute {
            pendingRoute = nil
            apply(route: route)
        }
    }

    // MARK: - PR Review, Merge & Stacked Train

    public func addInlineReviewDraft(prID: String, filePath: String, lineNumber: Int, side: DiffSide = .new, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = pendingInlineDrafts[prID] ?? []
        list.append(InlineReviewDraft(filePath: filePath, lineNumber: lineNumber, side: side, body: trimmed))
        pendingInlineDrafts[prID] = list
        showToast("已暂存行内评审 (\(list.count))")
    }

    @discardableResult
    public func submitPRReview(prID: String, decision: PRReviewDecision, summary: String) async -> Bool {
        guard let idx = pullRequests.firstIndex(where: { $0.id == prID }) else { return false }
        let drafts = pendingInlineDrafts[prID] ?? []
        let pr = pullRequests[idx]

        guard await performRepoOperation(pr.repoFullName, operation: { client, owner, repo in
            try await client.submitPullReview(
                owner: owner, repo: repo, index: pr.number, decision: decision, body: summary, comments: drafts
            )
        }) else { return false }
        guard let idx = pullRequests.firstIndex(where: { $0.id == prID }) else { return false }

        let author = profile.username.isEmpty ? "演示用户" : profile.username
        for draft in drafts {
            pullRequests[idx].comments.append(
                PRTimelineComment(
                    id: UUID().uuidString, author: author, body: draft.body,
                    filePath: draft.filePath, lineNumber: draft.lineNumber, side: draft.side, timestampText: "刚刚"
                )
            )
        }
        let note = summary.isEmpty ? decision.label : "\(decision.label)：\(summary)"
        pullRequests[idx].comments.append(
            PRTimelineComment(id: UUID().uuidString, author: author, body: note, timestampText: "刚刚")
        )
        pendingInlineDrafts[prID] = []
        showToast("已提交评审")
        return true
    }

    @discardableResult
    public func mergePullRequest(prID: String, strategy: PRMergeStrategy) async -> Bool {
        guard let idx = pullRequests.firstIndex(where: { $0.id == prID }) else { return false }
        let pr = pullRequests[idx]
        guard await performRepoOperation(pr.repoFullName, operation: { client, owner, repo in
            try await client.mergePullRequest(owner: owner, repo: repo, index: pr.number, strategy: strategy)
        }) else { return false }
        guard let idx = pullRequests.firstIndex(where: { $0.id == prID }) else { return false }
        pullRequests[idx].state = .merged
        // Advance stacked PR base if the next PR targets this head branch
        for nextIdx in pullRequests.indices where isDemoMode && pullRequests[nextIdx].baseBranch == pr.headBranch {
            pullRequests[nextIdx].baseBranch = pr.baseBranch
        }
        showToast("已合并 PR #\(pr.number)")
        syncWidgetSnapshot()
        return true
    }

    // MARK: - Repo Ops (Mirror & Webhooks)

    public func triggerMirrorSync(repoID: String) async {
        guard let idx = repositories.firstIndex(where: { $0.id == repoID }) else { return }
        let repo = repositories[idx]
        guard await performLiveOperation({ client in
            try await client.triggerMirrorSync(owner: repo.owner, repo: repo.name)
        }) else { return }
        guard let idx = repositories.firstIndex(where: { $0.id == repoID }) else { return }
        if isDemoMode {
            repositories[idx].lastMirrorSyncText = "刚刚"
            repositories[idx].updatedAtText = "刚刚"
        }
        showToast("\(repo.name) 镜像同步已触发")
    }

    public func replayWebhook(repoFullName: String, hookID: String) async {
        let key = canonicalRepoName(repoFullName)
        guard var hooks = webhooksByRepo[key],
              let idx = hooks.firstIndex(where: { $0.id == hookID }) else { return }
        guard await performRepoOperation(key, operation: { client, owner, repo in
            try await client.replayWebhookTest(owner: owner, repo: repo, hookID: hooks[idx].numericID)
        }) else { return }
        if !isDemoMode {
            showToast("Webhook 测试请求已提交，送达结果待服务器确认")
            return
        }
        hooks[idx].lastStatusCode = 200
        hooks[idx].deliveries.insert(
            WebhookDelivery(id: UUID().uuidString, statusCode: 200, deliveredAtText: "刚刚", eventName: "replay", responseSummary: "OK"),
            at: 0
        )
        webhooksByRepo[key] = hooks
        showToast("Webhook 重放成功 (200)")
    }

    // MARK: - Actions, Inbox & Admin Ops

    public func updateRunStatus(runID: String, to newStatus: RunStatus) {
        guard demoOnly("更改运行状态") else { return }
        guard let idx = runs.firstIndex(where: { $0.id == runID }) else { return }
        runs[idx].status = newStatus
        if newStatus == .running {
            runs[idx].durationSeconds = 1
            startLiveActivity(for: runs[idx])
        }
        syncWidgetSnapshot()
        showToast("构建 #\(runs[idx].runNumber) -> \(newStatus.badgeLabel)")
    }

    public func dispatchWorkflow(run: WorkflowRun, ref: String, inputs: [String: String]) async {
        guard await performRepoOperation(run.repoFullName, operation: { client, owner, repo in
            try await client.dispatchWorkflow(owner: owner, repo: repo, workflow: run.workflowFile, ref: ref, inputs: inputs)
        }) else { return }
        if !isDemoMode {
            showToast("工作流触发请求已提交，运行结果待服务器确认")
            return
        }
        let nextNum = (runs.map(\.runNumber).max() ?? 186) + 1
        let step = WorkflowStepLog(
            id: "st-init", number: 1, name: "Dispatching \(run.workflowFile)",
            status: .running, durationSeconds: 1, isExpanded: true,
            lines: [ANSITerminalLine(id: "ld-1", lineNumber: 1, text: "Queued with \(inputs.count) inputs on \(ref)", severity: .info)]
        )
        let spawned = WorkflowRun(
            id: "run-\(nextNum)", runNumber: nextNum, jobID: Int64(9000 + nextNum),
            repoFullName: run.repoFullName, workflowName: run.workflowName, workflowFile: run.workflowFile,
            branch: ref, commitSHA: "HEAD", status: .running, runnerName: run.runnerName,
            durationSeconds: 1, inputs: run.inputs, steps: [step]
        )
        runs.insert(spawned, at: 0)
        selectedRunID = spawned.id
        syncWidgetSnapshot()
        showToast("已触发 #\(nextNum)")
    }

    @discardableResult
    public func generateRunnerRegistrationToken() async -> Bool {
        if let client = makeActiveClient() {
            do {
                let token = try await client.createRunnerRegistrationToken()
                lastRunnerRegistrationToken = token
                showToast("已生成节点注册令牌")
                return true
            } catch {
                showToast(error.localizedDescription)
                return false
            }
        }
        guard isDemoMode else { return false }
        lastRunnerRegistrationToken = "tp_reg_demo_\(Int.random(in: 100000...999999))"
        showToast("已生成演示注册令牌")
        return true
    }

    @discardableResult
    public func markThreadRead(_ threadID: String) async -> Bool {
        guard notifications.contains(where: { $0.id == threadID }) else { return false }
        guard await performLiveOperation({ client in
            try await client.markNotificationThreadRead(threadID: threadID)
        }) else { return false }
        guard let idx = notifications.firstIndex(where: { $0.id == threadID }) else { return false }
        notifications[idx].unread = false
        notifications[idx].category = .archived
        syncWidgetSnapshot()
        return true
    }

    public func markAllThreadsRead() async {
        for id in notifications.filter(\.unread).map(\.id) {
            guard await markThreadRead(id) else { return }
        }
        showToast("全部通知已标为已读")
    }

    public func triggerSimulatedBarkBanner() {
        guard demoOnly("模拟推送") else { return }
        simulatedPushBanner = NotificationThread(
            id: "bark-sim-\(Int.random(in: 100...999))", category: .ciAlert,
            repoFullName: "alex/web-deploy",
            subjectTitle: "CI 告警 · web-deploy #184 构建失败，点击定位报错行",
            subjectType: "ActionRun", unread: true, updatedAtText: "刚刚",
            deepLink: "teapulse://actions/alex/web-deploy/184?step=failed"
        )
    }

    public func toggleApprovePR(_ prID: String) async {
        if approvedPRIDs.contains(prID) {
            guard demoOnly("取消批准") else { return }
            approvedPRIDs.remove(prID)
            showToast("已取消批准标记")
            return
        }
        if await submitPRReview(prID: prID, decision: .approve, summary: "") {
            approvedPRIDs.insert(prID)
        }
    }

    public func selectEndpointChannel(_ channel: EndpointChannel) async {
        if isDemoMode {
            let useLAN = channel == .lanDirect && (profile.lanURL?.isEmpty == false)
            let chosen: EndpointChannel = useLAN ? .lanDirect : .publicProxy
            let targetURL = useLAN ? (profile.lanURL ?? profile.publicURL) : profile.publicURL
            let latency = useLAN ? lanLatencyMs : proxyLatencyMs
            profile.activeChannel = chosen
            health = EndpointHealth(channel: chosen, baseURL: targetURL, latencyMs: latency, serverVersion: health.serverVersion)
            syncWidgetSnapshot()
            showToast("已切换至 \(health.probePillText)")
            return
        }
        let targetURL: String
        if channel == .lanDirect {
            guard let lan = profile.lanURL?.trimmingCharacters(in: .whitespacesAndNewlines), !lan.isEmpty else {
                showToast("未配置内网直连地址")
                return
            }
            targetURL = lan
        } else {
            targetURL = profile.publicURL
        }
        let headers = credentialStore.loadCredentials(forProfileID: profile.id)?.customHeaders ?? [:]
        guard let measured = await probeService.measureHealthz(baseURL: targetURL, channel: channel, timeout: channel == .lanDirect ? 0.8 : 4.0, additionalHeaders: headers) else {
            showToast("所选信道探测不可达，保留当前连接"); return
        }
        if channel == .lanDirect { lanLatencyMs = measured.latencyMs } else { proxyLatencyMs = measured.latencyMs }
        profile.activeChannel = channel
        let updatedHealth = EndpointHealth(channel: measured.channel, baseURL: measured.baseURL, latencyMs: measured.latencyMs, serverVersion: resolvedServerVersion(from: measured.serverVersion))
        health = updatedHealth
        Self.saveProfile(profile, key: profileStorageKey, defaults: defaults)
        syncWidgetSnapshot()
        showToast("已切换至 \(updatedHealth.probePillText)")
    }

    public func toggleMuteRepo(_ repoFullName: String) {
        guard demoOnly("仓库静音") else { return }
        for idx in notifications.indices where notifications[idx].repoFullName.caseInsensitiveCompare(repoFullName) == .orderedSame { notifications[idx].isMutedRepo.toggle() }
        showToast("已切换仓库静音")
    }

    public func triggerCronTask(_ taskID: String) async {
        guard let idx = cronTasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard await performLiveOperation({ client in try await client.triggerCronTask(name: cronTasks[idx].name) }) else { return }
        if isDemoMode { cronTasks[idx].lastRunText = "刚刚"; cronTasks[idx].execTimes += 1 }
        showToast("已触发 \(cronTasks[idx].name)")
    }

    public func toggleUserProhibitLogin(_ userID: String) {
        guard demoOnly("更改用户登录权限") else { return }
        guard let idx = adminUsers.firstIndex(where: { $0.id == userID }) else { return }
        adminUsers[idx].prohibitLogin.toggle()
    }

    public func deletePackage(_ pkgID: String) {
        guard demoOnly("删除制品包") else { return }
        packages.removeAll { $0.id == pkgID }; showToast("已清理制品包")
    }
}
