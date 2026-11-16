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
    private struct CommentTarget: Equatable {
        let path: String
        let line: Int
        let side: DiffSide
    }

    @State private var commentingTarget: CommentTarget?
    @State private var draftBody = ""

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
        VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
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
                .frame(maxWidth: 220)
                Spacer()
                let draftCount = (store.pendingInlineDrafts[prID] ?? []).count
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
                                ScrollView(.horizontal, showsIndicators: false) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(hunk.lines) { line in
                                            unifiedRow(line, filePath: file.path)
                                        }
                                    }
                                }
                                .background(TeaPulseTheme.codeSurface)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(hunk.splitRows) { row in
                                            splitRowView(row, filePath: file.path)
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
    private func inlineBubbleList(entries: [(id: String, author: String, body: String)], lineNumber: Int) -> some View {
        ForEach(entries, id: \.id) { entry in
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

    private func unifiedRow(_ line: DiffLine, filePath: String) -> some View {
        let lineNum = line.newLineNumber ?? line.oldLineNumber ?? 1
        let side: DiffSide = line.kind == .deletion ? .old : .new
        let target = CommentTarget(path: filePath, line: lineNum, side: side)
        let matchedComments = inlineEntries(for: filePath, lineNumber: lineNum, side: side)
        let isCommentingHere = commentingTarget == target

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                guard allowsCommenting else { return }
                TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                    commentingTarget = isCommentingHere ? nil : target
                }
            } label: {
                HStack(spacing: TeaPulseSpacing.sm) {
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
            }
            .buttonStyle(.plain)

            inlineBubbleList(entries: matchedComments, lineNumber: lineNum)

            if isCommentingHere {
                inlineComposer(filePath: filePath, lineNumber: lineNum, side: side)
            }
        }
    }

    private func inlineEntries(for filePath: String, lineNumber: Int, side: DiffSide) -> [(id: String, author: String, body: String)] {
        var result: [(id: String, author: String, body: String)] = comments
            .filter { $0.filePath == filePath && $0.lineNumber == lineNumber && $0.side == side }
            .map { (id: $0.id, author: $0.author, body: $0.body) }
        let drafts = (store.pendingInlineDrafts[prID] ?? [])
            .filter { $0.filePath == filePath && $0.lineNumber == lineNumber && $0.side == side }
            .enumerated()
            .map { idx, draft in
                (id: "draft-\(filePath)-\(lineNumber)-\(idx)", author: "草稿", body: draft.body)
            }
        result.append(contentsOf: drafts)
        return result
    }

    private func splitRowView(_ row: SplitDiffRow, filePath: String) -> some View {
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                splitHalf(row.left, filePath: filePath, side: .old)
                    .frame(width: 280, alignment: .leading)
                splitHalf(row.right, filePath: filePath, side: .new)
                    .frame(width: 280, alignment: .leading)
            }
            if let oldLine = row.left?.oldLineNumber {
                inlineBubbleList(entries: inlineEntries(for: filePath, lineNumber: oldLine, side: .old), lineNumber: oldLine)
            }
            if let newLine = row.right?.newLineNumber {
                inlineBubbleList(entries: inlineEntries(for: filePath, lineNumber: newLine, side: .new), lineNumber: newLine)
            }
            if let target = commentingTarget, target.path == filePath,
               (target.side == .old && target.line == row.left?.oldLineNumber)
                || (target.side == .new && target.line == row.right?.newLineNumber) {
                inlineComposer(filePath: filePath, lineNumber: target.line, side: target.side)
            }
        }
    }

    private func splitHalf(_ line: DiffLine?, filePath: String, side: DiffSide) -> some View {
        let lineNumber = side == .old ? line?.oldLineNumber : line?.newLineNumber
        return Button {
            guard allowsCommenting else { return }
            if let targetLine = lineNumber {
                TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                    commentingTarget = CommentTarget(path: filePath, line: targetLine, side: side)
                }
            }
        } label: {
            HStack(spacing: TeaPulseSpacing.xs) {
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
        }
        .buttonStyle(.plain)
        .disabled(lineNumber == nil)
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
