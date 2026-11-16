import SwiftUI
import GiteaKit

public struct MermaidDiagramView: View {
    public let graph: MermaidGraph
    private let embedded: Bool

    public init(graph: MermaidGraph, embedded: Bool = false) {
        self.graph = graph
        self.embedded = embedded
    }

    public var body: some View {
        if embedded {
            content
                .padding(TeaPulseSpacing.sm)
                .background(TeaPulseTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
        } else {
            SurfaceCard { content }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            HStack {
                StatusBadge("Mermaid \(graph.direction)", tone: .tertiary)
                Spacer()
                Text("\(graph.nodes.count) 节点 · \(graph.edges.count) 边")
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    ForEach(graph.edges) { edge in
                        HStack(spacing: TeaPulseSpacing.xs) {
                            nodeBox(label(for: edge.from))
                            VStack(spacing: 2) {
                                if let lbl = edge.label {
                                    Text(lbl)
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.primary)
                                        .lineLimit(1)
                                }
                                Image(systemName: "arrow.right")
                                    .font(TeaPulseTypography.codeSm)
                                    .foregroundStyle(TeaPulseTheme.secondary)
                            }
                            nodeBox(label(for: edge.to))
                        }
                        .padding(TeaPulseSpacing.sm)
                        .background(TeaPulseTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func label(for id: String) -> String {
        graph.nodes.first(where: { $0.id == id })?.label ?? id
    }

    private func nodeBox(_ text: String) -> some View {
        Text(text)
            .font(TeaPulseTypography.codeSm)
            .foregroundStyle(TeaPulseTheme.onSurface)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, TeaPulseSpacing.sm)
            .padding(.vertical, TeaPulseSpacing.xs)
            .background(TeaPulseTheme.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous).stroke(TeaPulseTheme.primary.opacity(0.45), lineWidth: 1))
    }
}

public struct MarkdownDocumentView: View {
    public let markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        let blocks = MarkdownBlockParser.parse(markdown)
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            if blocks.isEmpty {
                Text(markdown)
                    .font(TeaPulseTypography.bodyMd)
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(blocks) { block in
                    blockView(block, isFirst: block.id == blocks.first?.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(TeaPulseTheme.primary)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock, isFirst: Bool) -> some View {
        switch block.kind {
        case .heading(let level, let text):
            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                Text(inlineAttributedString(text))
                    .font(headingFont(level))
                    .fontWeight(level >= 3 ? .semibold : .bold)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                if level <= 2 {
                    Rectangle()
                        .fill(TeaPulseTheme.cardBorder)
                        .frame(height: 1)
                }
            }
            .padding(.top, isFirst ? 0 : TeaPulseSpacing.sm)

        case .paragraph(let text):
            Text(inlineAttributedString(text))
                .font(TeaPulseTypography.bodyMd)
                .foregroundStyle(TeaPulseTheme.onSurface)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

        case .listItem(let indent, let marker, let text):
            HStack(alignment: .firstTextBaseline, spacing: TeaPulseSpacing.sm) {
                listMarkerView(marker)
                Text(inlineAttributedString(text))
                    .font(TeaPulseTypography.bodyMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(indent) * TeaPulseSpacing.md)

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                if let language {
                    Text(language)
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(TeaPulseSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))

        case .mermaid(let graph):
            MermaidDiagramView(graph: graph, embedded: true)

        case .blockquote(let text):
            HStack(alignment: .top, spacing: TeaPulseSpacing.sm) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(TeaPulseTheme.primary)
                    .frame(width: 3)
                Text(inlineAttributedString(text))
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(TeaPulseSpacing.sm)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))

        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)

        case .thematicBreak:
            Rectangle()
                .fill(TeaPulseTheme.cardBorder)
                .frame(height: 1)
                .padding(.vertical, TeaPulseSpacing.xs)
        }
    }

    @ViewBuilder
    private func listMarkerView(_ marker: MarkdownBlock.ListMarker) -> some View {
        switch marker {
        case .bullet:
            Text("•")
                .font(TeaPulseTypography.bodyMd)
                .fontWeight(.bold)
                .foregroundStyle(TeaPulseTheme.primary)
        case .ordered(let number):
            Text("\(number).")
                .font(TeaPulseTypography.codeSm)
                .monospacedDigit()
                .foregroundStyle(TeaPulseTheme.primary)
        case .task(let checked):
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(TeaPulseTypography.bodySm)
                .foregroundStyle(checked ? TeaPulseTheme.primary : TeaPulseTheme.secondary)
        }
    }

    private func tableView(headers: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: TeaPulseSpacing.md, verticalSpacing: TeaPulseSpacing.xs) {
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in
                        Text(inlineAttributedString(cell))
                            .font(TeaPulseTypography.labelMd)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                    }
                }
                .padding(.bottom, TeaPulseSpacing.xs)

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(0..<max(headers.count, row.count), id: \.self) { col in
                            Text(inlineAttributedString(col < row.count ? row[col] : ""))
                                .font(TeaPulseTypography.bodySm)
                                .foregroundStyle(TeaPulseTheme.onSurface)
                        }
                    }
                }
            }
            .padding(TeaPulseSpacing.sm)
        }
        .background(TeaPulseTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return TeaPulseTypography.headlineLg
        case 2: return TeaPulseTypography.headlineMd
        default: return TeaPulseTypography.bodyMd
        }
    }

    private func inlineAttributedString(_ raw: String) -> AttributedString {
        guard var parsed = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return AttributedString(raw)
        }
        for run in parsed.runs where run.inlinePresentationIntent?.contains(.code) == true {
            parsed[run.range].font = TeaPulseTypography.codeSm
            parsed[run.range].foregroundColor = TeaPulseTheme.primary
            parsed[run.range].backgroundColor = TeaPulseTheme.surfaceElevated
        }
        return parsed
    }
}

public struct RepoFileDetailView: View {
    @Environment(AppStore.self) private var store
    public let repoFullName: String
    public let file: RepoFileEntry
    @State private var isLoading = false
    @State private var hasAttemptedLoad = false

    public init(repoFullName: String, file: RepoFileEntry) {
        self.repoFullName = repoFullName
        self.file = file
    }

    private var liveFile: RepoFileEntry {
        store.repoFiles[repoFullName]?.first { $0.path == file.path } ?? file
    }

    private var isMarkdownFile: Bool {
        let lower = liveFile.path.lowercased()
        return lower.hasSuffix(".md") || lower.hasSuffix(".markdown")
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                SurfaceCard {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                            Text(liveFile.path)
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.onSurface)
                                .lineLimit(2)
                            Text(liveFile.formattedSize)
                                .font(TeaPulseTypography.codeSm)
                                .monospacedDigit()
                                .foregroundStyle(TeaPulseTheme.secondary)
                        }
                        Spacer()
                        if let code = liveFile.content {
                            Button("复制") {
                                ClipboardService.copy(code)
                                store.showToast("已复制文件内容")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }

                if let code = liveFile.content {
                    if isMarkdownFile {
                        SurfaceCard {
                            MarkdownDocumentView(markdown: code)
                        }
                    } else {
                        SurfaceCard {
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(code)
                                    .font(TeaPulseTypography.codeSm)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                    .textSelection(.enabled)
                                    .padding(TeaPulseSpacing.md)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TeaPulseTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                        }
                    }
                } else if isLoading || (!store.isDemoMode && !hasAttemptedLoad) {
                    LoadingStateCard("正在加载文件内容…")
                } else {
                    SurfaceCard {
                        Text("未能加载文件内容")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface)
        .navigationTitle(liveFile.name.isEmpty ? liveFile.path : liveFile.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: file.path) {
            guard !store.isDemoMode, liveFile.content == nil else {
                hasAttemptedLoad = true
                return
            }
            isLoading = true
            await store.loadRepositoryFileContent(repoFullName: repoFullName, filePath: file.path)
            isLoading = false
            hasAttemptedLoad = true
        }
    }
}
