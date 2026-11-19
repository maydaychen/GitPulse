import SwiftUI
import GiteaKit

public struct DiffReaderView: View {
    public enum Mode: String, CaseIterable, Identifiable {
        case unified = "单栏对比"
        case split = "双栏对比"
        public var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let prID: String
    public let files: [DiffFilePatch]
    public let comments: [PRTimelineComment]
    public var isLoading = false
    public var allowsCommenting = true

    @State private var mode: Mode = .unified
    private struct CommentTarget: Hashable {
        let path: String
        let line: Int
        let side: DiffSide
    }

    private struct InlineEntry: Identifiable {
        let id: String
        let author: String
        let body: String
    }

    @State private var commentingTarget: CommentTarget?
    @State private var draftBody = ""
    @State private var availableWidth: CGFloat = 560

    public init(
        prID: String,
        files: [DiffFilePatch],
        comments: [PRTimelineComment] = [],
        isLoading: Bool = false,
        allowsCommenting: Bool = true
    ) {
        self.prID = prID
        self.files = files
        self.comments = comments
        self.isLoading = isLoading
        self.allowsCommenting = allowsCommenting
    }

    public var body: some View {
        let drafts = allowsCommenting ? (store.pendingInlineDrafts[prID] ?? []) : []
        let draftCount = drafts.count
        let inlineLookup = buildInlineLookup(drafts: drafts)

        LazyVStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
            HStack {
                Picker("对比模式", selection: Binding(
                    get: { mode },
                    set: { next in TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) { mode = next } }
                )) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
                Spacer()
                if allowsCommenting, draftCount > 0 {
                    StatusBadge("草稿 \(draftCount)", tone: .warning)
                        .teaPulseNumericTransition(value: draftCount)
                }
            }

            if files.isEmpty {
                if isLoading {
                    LoadingStateCard("正在加载代码变更对比…")
                } else {
                    SurfaceCard {
                        Text("暂无代码变更对比")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            ForEach(files) { file in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        Text(file.path)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Spacer()
                        Text("+\(file.additions) -\(file.deletions)")
                            .font(TeaPulseTypography.codeSm)
                            .monospacedDigit()
                            .foregroundStyle(TeaPulseTheme.primary)
                    }
                    .padding(TeaPulseSpacing.sm)
                    .background(TeaPulseTheme.surfaceElevated)

                    ForEach(file.hunks) { hunk in
                        Text(hunk.header)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.codeTertiary)
                            .padding(.horizontal, TeaPulseSpacing.sm)
                            .padding(.vertical, TeaPulseSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TeaPulseTheme.codeSurface)

                        Group {
                            if mode == .unified {
                                ScrollView(.horizontal, showsIndicators: TeaPulsePlatform.showsCodeHorizontalIndicators) {
                                    LazyVStack(alignment: .leading, spacing: 0) {
                                        ForEach(hunk.lines) { line in
                                            unifiedRow(line, filePath: file.path, inlineLookup: inlineLookup)
                                        }
                                    }
                                }
                                .background(TeaPulseTheme.codeSurface)
                            } else {
                                ScrollView(.horizontal, showsIndicators: TeaPulsePlatform.showsCodeHorizontalIndicators) {
                                    LazyVStack(alignment: .leading, spacing: 0) {
                                        ForEach(hunk.splitRows) { row in
                                            splitRowView(row, filePath: file.path, inlineLookup: inlineLookup)
                                        }
                                    }
                                }
                                .background(TeaPulseTheme.codeSurface)
                            }
                        }
                        .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: mode)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
    }

    @ViewBuilder
    private func inlineComposer(filePath: String, lineNumber: Int, side: DiffSide) -> some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                Text("\(filePath):\(side == .old ? "旧行" : "新行") L\(lineNumber)")
                    .font(TeaPulseTypography.codeSm)
                    .foregroundStyle(TeaPulseTheme.primary)
                TextField("输入行内评审意见…", text: $draftBody)
                    .textFieldStyle(.plain)
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .padding(TeaPulseSpacing.sm)
                    .background(TeaPulseTheme.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
            HStack(spacing: TeaPulseSpacing.sm) {
                Button("取消") {
                    TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                        commentingTarget = nil
                        draftBody = ""
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                Spacer()
                Button("暂存批注") {
                    TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                        store.addInlineReviewDraft(
                            prID: prID,
                            filePath: filePath,
                            lineNumber: lineNumber,
                            side: side,
                            body: draftBody
                        )
                        commentingTarget = nil
                        draftBody = ""
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }
    .padding(.horizontal, TeaPulseSpacing.sm)
    .padding(.vertical, TeaPulseSpacing.xs)
    .frame(maxWidth: 340, alignment: .leading)
    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func inlineBubbleList(entries: [InlineEntry], lineNumber: Int) -> some View {
        ForEach(entries) { entry in
            HStack(spacing: TeaPulseSpacing.xs) {
                Text("@\(entry.author)")
                    .font(TeaPulseTypography.codeSm)
                    .foregroundStyle(TeaPulseTheme.primary)
                Text("L\(lineNumber)")
                    .font(TeaPulseTypography.codeSm)
                    .foregroundStyle(TeaPulseTheme.tertiary)
                Text(entry.body)
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.onSurface)
            }
            .padding(.horizontal, TeaPulseSpacing.sm)
            .padding(.vertical, TeaPulseSpacing.xs)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.vertical, TeaPulseSpacing.xs)
        }
    }

    private func buildInlineLookup(drafts: [InlineReviewDraft]) -> [CommentTarget: [InlineEntry]] {
        var map: [CommentTarget: [InlineEntry]] = [:]
        for comment in comments {
            guard let path = comment.filePath, let line = comment.lineNumber else { continue }
            let target = CommentTarget(path: path, line: line, side: comment.side)
            map[target, default: []].append(InlineEntry(id: comment.id, author: comment.author, body: comment.body))
        }
        for (idx, draft) in drafts.enumerated() {
            let target = CommentTarget(path: draft.filePath, line: draft.lineNumber, side: draft.side)
            map[target, default: []].append(
                InlineEntry(id: "draft-\(draft.filePath)-\(draft.lineNumber)-\(idx)", author: "草稿", body: draft.body)
            )
        }
        return map
    }

    private func unifiedRow(
        _ line: DiffLine,
        filePath: String,
        inlineLookup: [CommentTarget: [InlineEntry]]
    ) -> some View {
        let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 1
        let side: DiffSide = line.kind == .deletion ? .old : .new
        let target = CommentTarget(path: filePath, line: lineNum, side: side)
        let matchedComments = inlineLookup[target] ?? []
        let isCommentingHere = commentingTarget == target

        let rowLabel = HStack(spacing: TeaPulseSpacing.sm) {
            Text(line.oldLineNumber.map(String.init) ?? "")
                .frame(width: 34, alignment: .trailing)
                .foregroundStyle(TeaPulseTheme.codeMuted)
            Text(line.newLineNumber.map(String.init) ?? "")
                .frame(width: 34, alignment: .trailing)
                .foregroundStyle(TeaPulseTheme.codeMuted)
            Text(prefixSymbol(line.kind))
                .foregroundStyle(prefixColor(line.kind))
            Text(line.content)
                .foregroundStyle(TeaPulseTheme.codeText)
            Spacer(minLength: TeaPulseSpacing.md)
        }
        .font(TeaPulseTypography.codeMd)
        .monospacedDigit()
        .padding(.horizontal, TeaPulseSpacing.sm)
        .padding(.vertical, 2)
        .background(rowBackground(line.kind))
        .contentShape(Rectangle())

        return VStack(alignment: .leading, spacing: 0) {
            if allowsCommenting {
                Button {
                    TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                        commentingTarget = isCommentingHere ? nil : target
                    }
                } label: {
                    rowLabel
                }
                .buttonStyle(.plain)
            } else {
                rowLabel
            }

            inlineBubbleList(entries: matchedComments, lineNumber: lineNum)

            if isCommentingHere {
                inlineComposer(filePath: filePath, lineNumber: lineNum, side: side)
            }
        }
    }

    private func splitRowView(
        _ row: SplitDiffRow,
        filePath: String,
        inlineLookup: [CommentTarget: [InlineEntry]]
    ) -> some View {
        let splitHalfWidth = max(280, floor((availableWidth - 1) / 2))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                splitHalf(row.left, filePath: filePath, side: .old)
                    .frame(width: splitHalfWidth, alignment: .leading)
                splitHalf(row.right, filePath: filePath, side: .new)
                    .frame(width: splitHalfWidth, alignment: .leading)
            }
            if let oldLine = row.left?.oldLineNumber,
               let entries = inlineLookup[CommentTarget(path: filePath, line: oldLine, side: .old)] {
                inlineBubbleList(entries: entries, lineNumber: oldLine)
            }
            if let newLine = row.right?.newLineNumber,
               let entries = inlineLookup[CommentTarget(path: filePath, line: newLine, side: .new)] {
                inlineBubbleList(entries: entries, lineNumber: newLine)
            }
            if let target = commentingTarget, target.path == filePath,
               (target.side == .old && target.line == row.left?.oldLineNumber)
                || (target.side == .new && target.line == row.right?.newLineNumber) {
                inlineComposer(filePath: filePath, lineNumber: target.line, side: target.side)
            }
        }
    }

    @ViewBuilder
    private func splitHalf(_ line: DiffLine?, filePath: String, side: DiffSide) -> some View {
        let lineNumber = side == .old ? line?.oldLineNumber : line?.newLineNumber
        let halfLabel = HStack(spacing: TeaPulseSpacing.xs) {
            Text(lineNumber.map(String.init) ?? "")
                .frame(width: 28, alignment: .trailing)
                .foregroundStyle(TeaPulseTheme.codeMuted)
            Text(line?.content ?? "")
                .foregroundStyle(TeaPulseTheme.codeText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(TeaPulseTypography.codeSm)
        .monospacedDigit()
        .padding(.horizontal, TeaPulseSpacing.xs)
        .padding(.vertical, 2)
        .background(line.map { rowBackground($0.kind) } ?? TeaPulseTheme.codeSurface)
        .contentShape(Rectangle())

        if allowsCommenting, let targetLine = lineNumber {
            Button {
                TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                    commentingTarget = CommentTarget(path: filePath, line: targetLine, side: side)
                }
            } label: {
                halfLabel
            }
            .buttonStyle(.plain)
        } else {
            halfLabel
        }
    }

    private func prefixSymbol(_ kind: DiffLineKind) -> String {
        switch kind {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        }
    }

    private func prefixColor(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: return TeaPulseTheme.codePrimary
        case .deletion: return TeaPulseTheme.codeError
        case .context: return TeaPulseTheme.codeMuted
        }
    }

    private func rowBackground(_ kind: DiffLineKind) -> Color {
        switch kind {
        case .addition: return TeaPulseTheme.diffAddHighlight
        case .deletion: return TeaPulseTheme.diffDeleteHighlight
        case .context: return TeaPulseTheme.codeSurface
        }
    }
}
