import Foundation

public struct MermaidGraph: Sendable, Equatable {
    public struct Node: Identifiable, Sendable, Equatable {
        public let id: String
        public var label: String

        public init(id: String, label: String) {
            self.id = id
            self.label = label
        }
    }

    public struct Edge: Identifiable, Sendable, Equatable {
        public let id: String
        public var from: String
        public var to: String
        public var label: String?

        public init(id: String, from: String, to: String, label: String? = nil) {
            self.id = id
            self.from = from
            self.to = to
            self.label = label
        }
    }

    public var direction: String
    public var nodes: [Node]
    public var edges: [Edge]

    public init(direction: String, nodes: [Node], edges: [Edge]) {
        self.direction = direction
        self.nodes = nodes
        self.edges = edges
    }
}

public enum MermaidParser {
    public static func extractFirstDiagram(from markdown: String) -> MermaidGraph? {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var inMermaid = false
        var blockLines: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```mermaid") {
                inMermaid = true
                continue
            }
            if inMermaid && trimmed.hasPrefix("```") {
                break
            }
            if inMermaid {
                blockLines.append(trimmed)
            }
        }
        guard !blockLines.isEmpty else { return nil }
        return parse(lines: blockLines)
    }

    public static func parse(lines: [String]) -> MermaidGraph? {
        var direction = "LR"
        var nodeMap: [String: String] = [:]
        var nodeOrder: [String] = []
        var edges: [MermaidGraph.Edge] = []

        func registerNode(_ rawToken: String) -> String {
            let trimmed = rawToken.trimmingCharacters(in: .whitespaces)
            if let openBracket = trimmed.firstIndex(of: "["),
               let closeBracket = trimmed.lastIndex(of: "]"),
               openBracket < closeBracket {
                let id = String(trimmed[..<openBracket]).trimmingCharacters(in: .whitespaces)
                let label = String(trimmed[trimmed.index(after: openBracket)..<closeBracket])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if nodeMap[id] == nil { nodeOrder.append(id) }
                nodeMap[id] = label
                return id
            }
            if nodeMap[trimmed] == nil {
                nodeOrder.append(trimmed)
                nodeMap[trimmed] = trimmed
            }
            return trimmed
        }

        for line in lines {
            if line.hasPrefix("flowchart ") || line.hasPrefix("graph ") {
                direction = line.contains("TD") ? "TD" : "LR"
                continue
            }
            if let arrowRange = line.range(of: "-->") {
                let left = String(line[..<arrowRange.lowerBound])
                var right = String(line[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                var edgeLabel: String?
                if right.hasPrefix("|"), let secondBar = right.dropFirst().firstIndex(of: "|") {
                    edgeLabel = String(right[right.index(after: right.startIndex)..<secondBar])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    right = String(right[right.index(after: secondBar)...])
                }
                let fromID = registerNode(left)
                let toID = registerNode(right)
                edges.append(
                    MermaidGraph.Edge(
                        id: "edge-\(edges.count)-\(fromID)-\(toID)",
                        from: fromID,
                        to: toID,
                        label: edgeLabel
                    )
                )
            }
        }

        guard !nodeOrder.isEmpty else { return nil }
        let nodes = nodeOrder.map { MermaidGraph.Node(id: $0, label: nodeMap[$0] ?? $0) }
        return MermaidGraph(direction: direction, nodes: nodes, edges: edges)
    }
}

public struct MarkdownBlock: Identifiable, Sendable, Equatable {
    public enum ListMarker: Sendable, Equatable {
        case bullet
        case ordered(Int)
        case task(checked: Bool)
    }

    public enum Kind: Sendable, Equatable {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case listItem(indent: Int, marker: ListMarker, text: String)
        case codeBlock(language: String?, code: String)
        case mermaid(MermaidGraph)
        case blockquote(text: String)
        case table(headers: [String], rows: [[String]])
        case thematicBreak
    }

    public let id: String
    public let kind: Kind

    public init(id: String, kind: Kind) {
        self.id = id
        self.kind = kind
    }
}

public enum MarkdownBlockParser {
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [MarkdownBlock] = []
        var i = frontmatterEndIndex(in: lines)

        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                i += 1
                continue
            }

            if let fence = parseFence(trimmed) {
                i += 1
                var codeLines: [String] = []
                while i < lines.count {
                    let candidate = lines[i].trimmingCharacters(in: .whitespaces)
                    if isClosingFence(candidate, marker: fence.marker) {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                if fence.language?.lowercased() == "mermaid",
                   let graph = MermaidParser.parse(lines: codeLines.map { $0.trimmingCharacters(in: .whitespaces) }) {
                    blocks.append(MarkdownBlock(id: "md-\(blocks.count)", kind: .mermaid(graph)))
                } else {
                    blocks.append(MarkdownBlock(id: "md-\(blocks.count)", kind: .codeBlock(
                        language: fence.language,
                        code: codeLines.joined(separator: "\n")
                    )))
                }
                continue
            }

            if isThematicBreak(trimmed) {
                blocks.append(MarkdownBlock(id: "md-\(blocks.count)", kind: .thematicBreak))
                i += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(MarkdownBlock(id: "md-\(blocks.count)", kind: .heading(level: heading.level, text: heading.text)))
                i += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let qTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                    guard qTrimmed.hasPrefix(">") else { break }
                    var content = String(qTrimmed.dropFirst())
                    if content.hasPrefix(" ") { content.removeFirst() }
                    quoteLines.append(content)
                    i += 1
                }
                let quoteText = quoteLines.filter { !$0.isEmpty }.joined(separator: "\n")
                if !quoteText.isEmpty {
                    blocks.append(MarkdownBlock(id: "md-\(blocks.count)", kind: .blockquote(text: quoteText)))
                }
                continue
            }

            if trimmed.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                let headers = parseTableCells(trimmed)
                i += 2
                var rows: [[String]] = []
                while i < lines.count {
                    let rowTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                    guard !rowTrimmed.isEmpty, rowTrimmed.contains("|") else { break }
                    rows.append(parseTableCells(rowTrimmed))
                    i += 1
                }
                blocks.append(MarkdownBlock(id: "md-\(blocks.count)", kind: .table(headers: headers, rows: rows)))
                continue
            }

            if let listItem = parseListItem(raw) {
                var text = listItem.text
                i += 1
                while i < lines.count {
                    let nextRaw = lines[i]
                    let nextTrimmed = nextRaw.trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.isEmpty || startsNewBlock(lines: lines, index: i) {
                        break
                    }
                    let leading = nextRaw.prefix(while: { $0 == " " || $0 == "\t" }).count
                    guard leading >= 2 else { break }
                    text += " " + nextTrimmed
                    i += 1
                }
                blocks.append(MarkdownBlock(id: "md-\(blocks.count)", kind: .listItem(
                    indent: listItem.indent,
                    marker: listItem.marker,
                    text: text
                )))
                continue
            }

            var paraLines: [String] = [trimmed]
            i += 1
            while i < lines.count {
                let nextTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                if nextTrimmed.isEmpty || startsNewBlock(lines: lines, index: i) {
                    break
                }
                paraLines.append(nextTrimmed)
                i += 1
            }
            blocks.append(MarkdownBlock(id: "md-\(blocks.count)", kind: .paragraph(text: paraLines.joined(separator: " "))))
        }

        return blocks
    }

    private static func frontmatterEndIndex(in lines: [String]) -> Int {
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return 0 }
        for idx in 1..<min(lines.count, 80) {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "..." {
                return idx + 1
            }
        }
        return 0
    }

    private static func startsNewBlock(lines: [String], index: Int) -> Bool {
        let raw = lines[index]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if parseFence(trimmed) != nil || isThematicBreak(trimmed) || parseHeading(trimmed) != nil {
            return true
        }
        if trimmed.hasPrefix(">") || parseListItem(raw) != nil {
            return true
        }
        if trimmed.contains("|"), index + 1 < lines.count, isTableSeparator(lines[index + 1]) {
            return true
        }
        return false
    }

    private static func parseFence(_ trimmed: String) -> (marker: String, language: String?)? {
        for ch: Character in ["`", "~"] {
            let count = trimmed.prefix(while: { $0 == ch }).count
            if count >= 3 {
                let rest = trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces)
                if ch == "`" && rest.contains("`") { return nil }
                let lang = rest.split(separator: " ").first.map(String.init)
                return (String(repeating: ch, count: count), lang?.isEmpty == true ? nil : lang)
            }
        }
        return nil
    }

    private static func isClosingFence(_ trimmed: String, marker: String) -> Bool {
        guard let ch = marker.first else { return false }
        let count = trimmed.prefix(while: { $0 == ch }).count
        return count >= marker.count && trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func isThematicBreak(_ trimmed: String) -> Bool {
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let ch = compact.first, ch == "-" || ch == "*" || ch == "_" else {
            return false
        }
        return compact.allSatisfy { $0 == ch }
    }

    private static func parseHeading(_ trimmed: String) -> (level: Int, text: String)? {
        let hashes = trimmed.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes) else { return nil }
        let remainder = trimmed.dropFirst(hashes)
        guard remainder.isEmpty || remainder.first == " " || remainder.first == "\t" else { return nil }
        var text = remainder.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") && (text.dropLast().isEmpty || text.dropLast().last == " ") {
            text = text.dropLast().trimmingCharacters(in: .whitespaces)
        }
        guard !text.isEmpty else { return nil }
        return (hashes, text)
    }

    private static func parseListItem(_ raw: String) -> (indent: Int, marker: MarkdownBlock.ListMarker, text: String)? {
        let expanded = raw.replacingOccurrences(of: "\t", with: "    ")
        let leadingSpaces = expanded.prefix(while: { $0 == " " }).count
        let trimmed = String(expanded.dropFirst(leadingSpaces))
        let indent = min(leadingSpaces / 2, 4)

        for prefix in ["- [ ] ", "* [ ] ", "+ [ ] "] where trimmed.hasPrefix(prefix) {
            return (indent, .task(checked: false), String(trimmed.dropFirst(prefix.count)))
        }
        for prefix in ["- [x] ", "- [X] ", "* [x] ", "* [X] ", "+ [x] ", "+ [X] "] where trimmed.hasPrefix(prefix) {
            return (indent, .task(checked: true), String(trimmed.dropFirst(prefix.count)))
        }
        for prefix in ["- ", "* ", "+ "] where trimmed.hasPrefix(prefix) {
            return (indent, .bullet, String(trimmed.dropFirst(prefix.count)))
        }

        let digits = trimmed.prefix(while: { $0.isNumber })
        if !digits.isEmpty, let number = Int(digits) {
            let afterDigits = trimmed.dropFirst(digits.count)
            if afterDigits.hasPrefix(". ") || afterDigits.hasPrefix(") ") {
                return (indent, .ordered(number), String(afterDigits.dropFirst(2)))
            }
        }
        return nil
    }

    private static func isTableSeparator(_ rawLine: String) -> Bool {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-") && trimmed.contains("|") else { return false }
        let cells = parseTableCells(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let inner = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return inner.count >= 3 && inner.allSatisfy { $0 == "-" }
        }
    }

    private static func parseTableCells(_ trimmed: String) -> [String] {
        var stripped = trimmed
        if stripped.hasPrefix("|") { stripped.removeFirst() }
        if stripped.hasSuffix("|") { stripped.removeLast() }
        return stripped.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
