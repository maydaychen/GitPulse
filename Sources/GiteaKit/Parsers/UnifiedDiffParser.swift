import Foundation

public enum UnifiedDiffParser {
    public static func parse(_ rawDiff: String) -> [DiffFilePatch] {
        let lines = rawDiff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var patches: [DiffFilePatch] = []
        var currentPath: String?
        var currentStatus = "modified"
        var currentHunks: [DiffHunk] = []
        var currentHunkHeader: String?
        var currentLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0
        var additions = 0
        var deletions = 0

        func flushHunk() {
            guard let header = currentHunkHeader else { return }
            let split = buildSplitRows(from: currentLines, prefix: header)
            currentHunks.append(
                DiffHunk(
                    id: "hunk-\(currentHunks.count)-\(header.hashValue)",
                    header: header,
                    lines: currentLines,
                    splitRows: split
                )
            )
            currentHunkHeader = nil
            currentLines = []
        }

        func flushFile() {
            flushHunk()
            guard let path = currentPath else { return }
            patches.append(
                DiffFilePatch(
                    id: "file-\(path)",
                    path: path,
                    status: currentStatus,
                    additions: additions,
                    deletions: deletions,
                    hunks: currentHunks
                )
            )
            currentPath = nil
            currentStatus = "modified"
            currentHunks = []
            additions = 0
            deletions = 0
        }

        for (idx, line) in lines.enumerated() {
            if line.hasPrefix("diff --git ") {
                flushFile()
                currentPath = extractPath(fromDiffGitLine: line)
                continue
            }
            if line.hasPrefix("new file mode") {
                currentStatus = "added"
                continue
            }
            if line.hasPrefix("deleted file mode") {
                currentStatus = "deleted"
                continue
            }
            if line.hasPrefix("+++ b/") {
                currentPath = String(line.dropFirst("+++ b/".count))
                continue
            }
            if line.hasPrefix("--- ") || line.hasPrefix("index ") {
                continue
            }
            if line.hasPrefix("@@ ") {
                flushHunk()
                currentHunkHeader = line
                let numbers = parseHunkRange(line)
                oldLine = numbers.oldStart
                newLine = numbers.newStart
                continue
            }
            guard currentHunkHeader != nil else { continue }
            // This is diff metadata, not a line in either file.
            if line.hasPrefix("\\ No newline at end of file") || line.isEmpty { continue }

            if line.hasPrefix("+") {
                additions += 1
                currentLines.append(
                    DiffLine(
                        id: "dl-\(idx)-add-\(newLine)",
                        kind: .addition,
                        oldLineNumber: nil,
                        newLineNumber: newLine,
                        content: String(line.dropFirst())
                    )
                )
                newLine += 1
            } else if line.hasPrefix("-") {
                deletions += 1
                currentLines.append(
                    DiffLine(
                        id: "dl-\(idx)-del-\(oldLine)",
                        kind: .deletion,
                        oldLineNumber: oldLine,
                        newLineNumber: nil,
                        content: String(line.dropFirst())
                    )
                )
                oldLine += 1
            } else {
                let text = line.hasPrefix(" ") ? String(line.dropFirst()) : line
                currentLines.append(
                    DiffLine(
                        id: "dl-\(idx)-ctx-\(oldLine)-\(newLine)",
                        kind: .context,
                        oldLineNumber: oldLine,
                        newLineNumber: newLine,
                        content: text
                    )
                )
                oldLine += 1
                newLine += 1
            }
        }

        flushFile()
        return patches
    }

    public static func buildSplitRows(from lines: [DiffLine], prefix: String = "") -> [SplitDiffRow] {
        var rows: [SplitDiffRow] = []
        var pendingDeletes: [DiffLine] = []
        var pendingAdds: [DiffLine] = []

        func flushPending() {
            let count = max(pendingDeletes.count, pendingAdds.count)
            for i in 0..<count {
                let left = i < pendingDeletes.count ? pendingDeletes[i] : nil
                let right = i < pendingAdds.count ? pendingAdds[i] : nil
                rows.append(
                    SplitDiffRow(
                        id: "split-\(prefix.hashValue)-\(rows.count)",
                        left: left,
                        right: right
                    )
                )
            }
            pendingDeletes.removeAll()
            pendingAdds.removeAll()
        }

        for line in lines {
            switch line.kind {
            case .deletion:
                pendingDeletes.append(line)
            case .addition:
                pendingAdds.append(line)
            case .context:
                flushPending()
                rows.append(
                    SplitDiffRow(
                        id: "split-\(prefix.hashValue)-\(rows.count)",
                        left: line,
                        right: line
                    )
                )
            }
        }
        flushPending()
        return rows
    }

    private static func extractPath(fromDiffGitLine line: String) -> String {
        let parts = line.split(separator: " ")
        if let last = parts.last, last.hasPrefix("b/") {
            return String(last.dropFirst(2))
        }
        return "unknown"
    }

    private static func parseHunkRange(_ header: String) -> (oldStart: Int, newStart: Int) {
        let parts = header.split(separator: " ")
        var oldStart = 1
        var newStart = 1
        for part in parts {
            if part.hasPrefix("-") {
                let num = part.dropFirst().split(separator: ",").first.flatMap { Int($0) }
                if let num { oldStart = num }
            } else if part.hasPrefix("+") {
                let num = part.dropFirst().split(separator: ",").first.flatMap { Int($0) }
                if let num { newStart = num }
            }
        }
        return (oldStart, newStart)
    }
}
