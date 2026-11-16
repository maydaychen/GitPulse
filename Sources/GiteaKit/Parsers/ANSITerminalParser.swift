import Foundation

public enum ANSITerminalParser {
    public static func parseSteps(from rawLog: String, runFailed: Bool = false) -> [WorkflowStepLog] {
        let rawLines = rawLog.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var steps: [WorkflowStepLog] = []
        var currentStepName = "执行日志"
        var currentStatus: RunStatus = runFailed ? .failure : .success
        var currentLines: [ANSITerminalLine] = []
        var stepCounter = 1
        var hasExplicitGroup = false

        func flushStep() {
            guard !currentLines.isEmpty || hasExplicitGroup else { return }
            let errorIdx = currentLines.firstIndex { $0.severity == .error }
            let finalStatus: RunStatus = errorIdx != nil ? .failure : currentStatus
            let duration = max(2, currentLines.count * 3)
            steps.append(
                WorkflowStepLog(
                    id: "step-\(stepCounter)",
                    number: stepCounter,
                    name: currentStepName,
                    status: finalStatus,
                    durationSeconds: duration,
                    isExpanded: finalStatus == .failure,
                    firstErrorLineIndex: errorIdx,
                    lines: currentLines
                )
            )
            stepCounter += 1
            currentLines = []
        }

        for (index, line) in rawLines.enumerated() {
            if let groupName = extractGroupHeader(line) {
                if !currentLines.isEmpty || hasExplicitGroup {
                    flushStep()
                }
                hasExplicitGroup = true
                currentStepName = groupName
                currentStatus = .success
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("::endgroup::") {
                flushStep()
                hasExplicitGroup = false
                continue
            }
            let parsed = parseANSILine(line, lineNumber: index + 1)
            if parsed.severity == .error {
                currentStatus = .failure
            }
            currentLines.append(parsed)
        }

        flushStep()
        return steps
    }

    public static func parseANSILine(_ rawLine: String, lineNumber: Int) -> ANSITerminalLine {
        var severity: ANSISeverity = .normal
        var cleaned = ""
        var cursor = rawLine.startIndex

        while let escRange = rawLine[cursor...].range(of: "\u{001B}[") {
            cleaned.append(contentsOf: rawLine[cursor..<escRange.lowerBound])
            let afterBracket = escRange.upperBound
            if let mIndex = rawLine[afterBracket...].firstIndex(of: "m") {
                let codeString = String(rawLine[afterBracket..<mIndex])
                severity = mapSGRCodes(codeString, fallback: severity)
                cursor = rawLine.index(after: mIndex)
            } else {
                cursor = afterBracket
            }
        }
        cleaned.append(contentsOf: rawLine[cursor...])

        let lower = cleaned.lowercased()
        if severity == .normal {
            if lower.contains("error:") || lower.contains("##[error]") || lower.contains("fatal:") || lower.contains("failed") {
                severity = .error
            } else if lower.contains("warning:") || lower.contains("warn") {
                severity = .warning
            } else if lower.contains("passed") || lower.contains("succeeded") {
                severity = .success
            }
        }

        return ANSITerminalLine(
            id: "line-\(lineNumber)-\(abs(cleaned.hashValue))",
            lineNumber: lineNumber,
            text: cleaned,
            severity: severity
        )
    }

    private static func extractGroupHeader(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("::group::") {
            return String(trimmed.dropFirst("::group::".count))
        }
        if trimmed.hasPrefix("##[group]") {
            return String(trimmed.dropFirst("##[group]".count))
        }
        return nil
    }

    private static func mapSGRCodes(_ codes: String, fallback: ANSISeverity) -> ANSISeverity {
        let parts = codes.split(separator: ";").compactMap { Int($0) }
        if parts.contains(0) {
            return fallback
        }
        if parts.contains(31) || parts.contains(91) {
            return .error
        }
        if parts.contains(32) || parts.contains(92) {
            return .success
        }
        if parts.contains(33) || parts.contains(93) {
            return .warning
        }
        if parts.contains(34) || parts.contains(36) || parts.contains(96) {
            return .info
        }
        if parts.contains(90) || parts.contains(2) {
            return .muted
        }
        return fallback
    }
}
