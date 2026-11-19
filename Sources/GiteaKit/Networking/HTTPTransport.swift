import Foundation

public struct HTTPResponseData: Sendable, Equatable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public enum GiteaClientError: Error, LocalizedError, Sendable, Equatable {
    case invalidBaseURL(String)
    case payloadTooLarge(limitHint: String)
    case unauthorized
    case httpStatus(Int, String)
    case networkFailure(String)
    case decodingFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let url):
            return "无效实例地址：\(url)"
        case .payloadTooLarge(let hint):
            return "HTTP 413：\(hint)"
        case .unauthorized:
            return "HTTP 401：PAT 无效或权限不足"
        case .httpStatus(let code, let message):
            return message.isEmpty ? "HTTP \(code)" : "HTTP \(code)：\(message)"
        case .networkFailure(let detail):
            return "网络失败：\(detail)"
        case .decodingFailure(let detail):
            return "响应解析失败：\(detail)"
        }
    }
}

public protocol HTTPTransport: Sendable {
    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData
}

public final class URLSessionHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession
    private let uploadSession: URLSession

    public init() {
        let standardConfig = URLSessionConfiguration.default
        standardConfig.timeoutIntervalForRequest = 20
        standardConfig.waitsForConnectivity = false
        self.session = URLSession(configuration: standardConfig)

        let uploadConfig = URLSessionConfiguration.default
        uploadConfig.timeoutIntervalForRequest = 300
        uploadConfig.timeoutIntervalForResource = 300
        self.uploadSession = URLSession(configuration: uploadConfig)
    }

    public func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        var tuned = request
        tuned.timeoutInterval = timeout
        let activeSession = timeout >= 120 ? uploadSession : session
        do {
            let (data, response) = try await activeSession.data(for: tuned)
            guard let http = response as? HTTPURLResponse else {
                throw GiteaClientError.networkFailure("非 HTTP 响应")
            }
            var normalizedHeaders: [String: String] = [:]
            for (k, v) in http.allHeaderFields {
                if let key = k as? String, let val = v as? String {
                    normalizedHeaders[key] = val
                }
            }
            return HTTPResponseData(statusCode: http.statusCode, headers: normalizedHeaders, body: data)
        } catch let err as GiteaClientError {
            throw err
        } catch {
            throw GiteaClientError.networkFailure(error.localizedDescription)
        }
    }
}

public func boundedConcurrentMap<Element: Sendable, Output: Sendable>(
    _ items: [Element],
    maxConcurrency: Int = 6,
    operation: @Sendable @escaping (Element) async -> Output
) async -> [Output] {
    guard !items.isEmpty, maxConcurrency > 0 else { return [] }
    return await withTaskGroup(of: (Int, Output).self, returning: [Output].self) { group in
        var results = Array<Output?>(repeating: nil, count: items.count)
        var nextIndex = 0
        let initialLimit = min(maxConcurrency, items.count)

        while nextIndex < initialLimit {
            let index = nextIndex
            let item = items[index]
            group.addTask { (index, await operation(item)) }
            nextIndex += 1
        }

        while let (index, value) = await group.next() {
            results[index] = value
            if nextIndex < items.count {
                let index = nextIndex
                let item = items[index]
                group.addTask { (index, await operation(item)) }
                nextIndex += 1
            }
        }

        return results.compactMap { $0 }
    }
}
