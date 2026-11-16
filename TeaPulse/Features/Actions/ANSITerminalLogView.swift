import SwiftUI
import GiteaKit

public struct WorkflowDispatchSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    public let run: WorkflowRun
    @State private var branch: String
    @State private var inputValues: [String: String]

    public init(run: WorkflowRun) {
        self.run = run
        self._branch = State(initialValue: run.branch)
        var initial: [String: String] = [:]
        for item in run.inputs {
            initial[item.key] = item.defaultValue
        }
        self._inputValues = State(initialValue: initial)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                        Text("目标分支")
                            .font(TeaPulseTypography.labelMd)
                            .foregroundStyle(TeaPulseTheme.secondary)
                        TextField("main", text: $branch)
                            .textFieldStyle(.plain)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .padding(TeaPulseSpacing.sm)
                            .background(TeaPulseTheme.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                    }

                    ForEach(run.inputs) { input in
                        VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                            Text(input.key)
                                .font(TeaPulseTypography.labelMd)
                                .foregroundStyle(TeaPulseTheme.secondary)
                            TextField(input.defaultValue, text: Binding(
                                get: { inputValues[input.key] ?? input.defaultValue },
                                set: { inputValues[input.key] = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .padding(TeaPulseSpacing.sm)
                            .background(TeaPulseTheme.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                        }
                    }

                    HStack {
                        Spacer()
                        Button("触发运行") {
                            Task {
                                await store.dispatchWorkflow(run: run, ref: branch, inputs: inputValues)
                                dismiss()
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }
                .padding(TeaPulseSpacing.md)
            }
            .background(TeaPulseTheme.surface)
            .navigationTitle("手动触发 \(run.workflowFile)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

public struct ANSITerminalLogView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let run: WorkflowRun

    @State private var expandedSteps: Set<String> = []
    @State private var showForceCancelConfirm = false
    @State private var showDispatchSheet = false

    public init(run: WorkflowRun) {
        self.run = run
    }

    private var liveRun: WorkflowRun {
        store.runs.first(where: { $0.id == run.id }) ?? run
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                    summaryHeader
                    actionToolbar
                    stepsTerminalCard
                    if !liveRun.artifacts.isEmpty {
                        artifactsCard
                    }
                }
                .padding(TeaPulseSpacing.md)
            }
            .background(TeaPulseTheme.surface)
            .task(id: liveRun.id) {
                await store.loadWorkflowRunLogs(for: liveRun)
                syncExpandedAndFocus(proxy: proxy)
            }
            .refreshable {
                await store.loadWorkflowRunLogs(for: liveRun, force: true)
                syncExpandedAndFocus(proxy: proxy)
            }
            .onAppear {
                syncExpandedAndFocus(proxy: proxy)
            }
        }
        .confirmationDialog("确认强制终止？", isPresented: $showForceCancelConfirm, titleVisibility: .visible) {
            Button("强制终止构建 #\(liveRun.runNumber)", role: .destructive) {
                store.updateRunStatus(runID: liveRun.id, to: .failure)
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showDispatchSheet) {
            WorkflowDispatchSheet(run: liveRun)
                .preferredColorScheme(store.themePreference.colorScheme)
        }
    }

    private var summaryHeader: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    StatusBadge(liveRun.status.badgeLabel, tone: liveRun.status.badgeTone)
                    Spacer()
                    Text(liveRun.durationText)
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.secondary)
                }

                Text("\(liveRun.workflowName) #\(liveRun.runNumber)")
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(liveRun.repoFullName)
                    .font(TeaPulseTypography.codeSm)
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        BranchRoutePill(liveRun.branch)
                        StatusBadge(liveRun.commitSHA, tone: .neutral)
                        StatusBadge(liveRun.runnerName, tone: .neutral)
                    }
                }
            }
        }
    }

    private var actionToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TeaPulseSpacing.sm) {
                if liveRun.status == .waitingApproval {
                    Button("批准执行") {
                        store.updateRunStatus(runID: liveRun.id, to: .running)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                } else {
                    Button("重新运行") {
                        store.updateRunStatus(runID: liveRun.id, to: .running)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }

                Button("手动触发") {
                    showDispatchSheet = true
                }
                .buttonStyle(SecondaryActionButtonStyle())

                #if os(iOS)
                Button("灵动岛") {
                    store.startLiveActivity(for: liveRun)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                #endif

                if liveRun.status == .running {
                    Button("取消运行") {
                        store.updateRunStatus(runID: liveRun.id, to: .failure)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button("强制终止") {
                        showForceCancelConfirm = true
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private var stepsTerminalCard: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            if store.isLoadingRunLogs(liveRun) {
                LoadingStateCard("正在拉取构建步骤与终端日志…")
            } else if liveRun.steps.isEmpty {
                SurfaceCard {
                    Text("暂无步骤日志输出")
                        .font(TeaPulseTypography.bodySm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ForEach(liveRun.steps) { step in
                let isOpen = expandedSteps.contains(step.id)
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) {
                            if isOpen {
                                expandedSteps.remove(step.id)
                            } else {
                                expandedSteps.insert(step.id)
                            }
                        }
                    } label: {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            Image(systemName: "chevron.right")
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                                .rotationEffect(.degrees(isOpen ? 90 : 0))
                            StatusBadge(step.status.badgeLabel, tone: step.status.badgeTone)
                            Text("\(step.number). \(step.name)")
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.onSurface)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text("\(step.durationSeconds)s")
                                .font(TeaPulseTypography.codeSm)
                                .monospacedDigit()
                                .foregroundStyle(TeaPulseTheme.secondary)
                        }
                        .padding(.horizontal, TeaPulseSpacing.md)
                        .padding(.vertical, TeaPulseSpacing.sm)
                        .frame(minHeight: 40)
                        .background(TeaPulseTheme.surfaceElevated)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TeaPulsePressableCardStyle())

                    if isOpen {
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(step.lines) { line in
                                    HStack(spacing: TeaPulseSpacing.sm) {
                                        Text("\(line.lineNumber)")
                                            .frame(width: 28, alignment: .trailing)
                                            .foregroundStyle(TeaPulseTheme.codeMuted)
                                        Text(line.text)
                                            .foregroundStyle(lineColor(line.severity))
                                        Spacer(minLength: TeaPulseSpacing.md)
                                    }
                                    .font(TeaPulseTypography.codeMd)
                                    .monospacedDigit()
                                    .padding(.horizontal, TeaPulseSpacing.sm)
                                    .padding(.vertical, 2)
                                    .background(line.severity == .error ? TeaPulseTheme.diffDeleteHighlight : Color.clear)
                                    .id(line.id)
                                }
                            }
                            .padding(.vertical, TeaPulseSpacing.sm)
                        }
                        .background(TeaPulseTheme.terminalSurface)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
            }
        }
    }

    private var artifactsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                Text("构建产物")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.secondary)
                ForEach(liveRun.artifacts, id: \.self) { artifact in
                    HStack {
                        Text(artifact)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                        Spacer()
                        Button("下载") {
                            store.showToast("制品下载暂未接入服务器")
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
        }
    }

    private func lineColor(_ severity: ANSISeverity) -> Color {
        switch severity {
        case .normal: return TeaPulseTheme.codeText
        case .info: return TeaPulseTheme.codeTertiary
        case .success: return TeaPulseTheme.codePrimary
        case .warning: return TeaPulseTheme.codeWarning
        case .error: return TeaPulseTheme.codeError
        case .muted: return TeaPulseTheme.codeMuted
        }
    }

    private func syncExpandedAndFocus(proxy: ScrollViewProxy) {
        expandedSteps = Set(liveRun.steps.filter(\.isExpanded).map(\.id))
        if let failedStep = liveRun.steps.first(where: { $0.status == .failure }),
           let errorIdx = failedStep.firstErrorLineIndex,
           failedStep.lines.indices.contains(errorIdx) {
            let targetID = failedStep.lines[errorIdx].id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                    proxy.scrollTo(targetID, anchor: .center)
                }
            }
        }
    }
}
