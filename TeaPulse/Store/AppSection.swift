import Foundation

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case pulse
    case repos
    case actions
    case inbox
    case ops

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pulse: return "概览"
        case .repos: return "仓库"
        case .actions: return "工作流"
        case .inbox: return "通知"
        case .ops: return "运维"
        }
    }

    public var systemImage: String {
        switch self {
        case .pulse: return "waveform.path.ecg"
        case .repos: return "folder.badge.gearshape"
        case .actions: return "play.rectangle.on.rectangle"
        case .inbox: return "tray.full"
        case .ops: return "server.rack"
        }
    }

    public var usesMasterDetailSplit: Bool {
        switch self {
        case .repos, .actions:
            return true
        case .pulse, .inbox, .ops:
            return false
        }
    }
}

public enum RepoWorkspaceTab: String, CaseIterable, Identifiable, Sendable {
    case readme = "概览"
    case files = "文件"
    case pullRequests = "合并请求"
    case issues = "议题"
    case ops = "运维设置"

    public var id: String { rawValue }
}

public enum PullRequestSegment: String, CaseIterable, Identifiable, Sendable {
    case overview = "概览"
    case diff = "代码变更"
    case checks = "检查状态"

    public var id: String { rawValue }
}

public enum ActionsFilterScope: String, CaseIterable, Identifiable, Sendable {
    case all = "全部"
    case running = "运行中"
    case waiting = "待审批"
    case failed = "失败"
    case runners = "执行节点"

    public var id: String { rawValue }
}

public struct CommandPaletteEntry: Identifiable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var badge: String
    public var deepLink: String

    public init(id: String, title: String, subtitle: String, badge: String, deepLink: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.deepLink = deepLink
    }
}

public enum ToastTone: String, Sendable, Equatable {
    case success
    case warning
    case error

    public var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    public static func infer(from message: String) -> ToastTone {
        let lower = message.lowercased()
        let errorKeywords = [
            "失败", "错误", "无效", "拒绝", "超限", "error", "unauthorized", "forbidden", "failed"
        ]
        if errorKeywords.contains(where: { lower.contains($0) }) {
            return .error
        }
        let warningKeywords = [
            "未找到", "未能", "不可达", "不可用", "请填写", "未配置", "暂未接入", "待服务器确认", "暂不支持"
        ]
        if warningKeywords.contains(where: { lower.contains($0) }) {
            return .warning
        }
        return .success
    }
}
