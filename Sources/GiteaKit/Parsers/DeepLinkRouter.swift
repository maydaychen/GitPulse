import Foundation

public enum TeaPulseRoute: Equatable, Sendable {
    case pulse
    case pullRequest(owner: String, repo: String, index: Int)
    case actionRun(owner: String, repo: String, runID: Int, focusFailedStep: Bool)
    case opsRunners
    case repository(owner: String, repo: String)

    public var deepLinkString: String {
        switch self {
        case .pulse:
            return "teapulse://pulse"
        case .pullRequest(let owner, let repo, let index):
            return "teapulse://pull/\(owner)/\(repo)/\(index)"
        case .actionRun(let owner, let repo, let runID, let focusFailedStep):
            let suffix = focusFailedStep ? "?step=failed" : ""
            return "teapulse://actions/\(owner)/\(repo)/\(runID)\(suffix)"
        case .opsRunners:
            return "teapulse://ops/runners"
        case .repository(let owner, let repo):
            return "teapulse://repo/\(owner)/\(repo)"
        }
    }

    public var displayTitle: String {
        switch self {
        case .pulse:
            return "概览脉冲看板"
        case .pullRequest(let owner, let repo, let index):
            return "\(owner)/\(repo) PR #\(index)"
        case .actionRun(let owner, let repo, let runID, _):
            return "\(owner)/\(repo) Run #\(runID)"
        case .opsRunners:
            return "Runners 在线监控"
        case .repository(let owner, let repo):
            return "\(owner)/\(repo)"
        }
    }
}

public enum DeepLinkRouter {
    public static func parse(_ urlString: String) -> TeaPulseRoute? {
        guard let url = URL(string: urlString) else { return nil }
        return parse(url)
    }

    public static func parse(_ url: URL) -> TeaPulseRoute? {
        if url.scheme?.lowercased() == "teapulse" {
            return parseTeaPulseScheme(url)
        }
        return parseSharedWebURL(url)
    }

    private static func parseTeaPulseScheme(_ url: URL) -> TeaPulseRoute? {
        let host = url.host?.lowercased() ?? ""
        let parts = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "pulse":
            return .pulse
        case "pull":
            guard parts.count >= 3, let index = Int(parts[2]) else { return nil }
            return .pullRequest(owner: parts[0], repo: parts[1], index: index)
        case "actions":
            guard parts.count >= 3, let runID = Int(parts[2]) else { return nil }
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let focusFailed = queryItems.contains { $0.name == "step" && $0.value == "failed" }
            return .actionRun(owner: parts[0], repo: parts[1], runID: runID, focusFailedStep: focusFailed)
        case "ops":
            if parts.first?.lowercased() == "runners" {
                return .opsRunners
            }
            return nil
        case "repo":
            guard parts.count >= 2 else { return nil }
            return .repository(owner: parts[0], repo: parts[1])
        default:
            return nil
        }
    }

    public static func parseSharedWebURL(_ url: URL) -> TeaPulseRoute? {
        let segments = url.pathComponents.filter { $0 != "/" }
        guard segments.count >= 2 else { return nil }

        // Handle optional reverse-proxy subpath prefix before <owner>/<repo>/...
        if let pullsIdx = segments.firstIndex(of: "pulls"),
           pullsIdx >= 2,
           pullsIdx + 1 < segments.count,
           let prNumber = Int(segments[pullsIdx + 1]) {
            return .pullRequest(
                owner: segments[pullsIdx - 2],
                repo: segments[pullsIdx - 1],
                index: prNumber
            )
        }

        if let actionsIdx = segments.firstIndex(of: "actions"),
           actionsIdx >= 2,
           actionsIdx + 2 < segments.count,
           segments[actionsIdx + 1] == "runs",
           let runID = Int(segments[actionsIdx + 2]) {
            return .actionRun(
                owner: segments[actionsIdx - 2],
                repo: segments[actionsIdx - 1],
                runID: runID,
                focusFailedStep: true
            )
        }

        if segments.contains("admin"), segments.contains("runners") {
            return .opsRunners
        }

        if segments.count == 2 {
            return .repository(owner: segments[0], repo: segments[1])
        }

        // Fallback: look for first plausible <owner>/<repo> followed by src/issues/releases
        let knownRepoSubpaths: Set<String> = ["src", "issues", "releases", "settings", "actions"]
        for i in 2..<segments.count where knownRepoSubpaths.contains(segments[i]) {
            return .repository(owner: segments[i - 2], repo: segments[i - 1])
        }
        return nil
    }
}
