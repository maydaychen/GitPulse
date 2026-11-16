import Foundation
@testable import GiteaKit

final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    struct RecordedRequest: Sendable {
        let method: String
        let url: URL
        let headers: [String: String]
        let body: Data?
        let timeout: TimeInterval
    }

    private let lock = NSLock()
    private var handler: @Sendable (URLRequest, TimeInterval) async throws -> HTTPResponseData
    private(set) var recordedRequests: [RecordedRequest] = []

    init(handler: @escaping @Sendable (URLRequest, TimeInterval) async throws -> HTTPResponseData) {
        self.handler = handler
    }

    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        if let url = request.url {
            let record = RecordedRequest(
                method: request.httpMethod ?? "GET",
                url: url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: request.httpBody,
                timeout: timeout
            )
            lock.withLock {
                recordedRequests.append(record)
            }
        }
        return try await handler(request, timeout)
    }

    func snapshotRequests() -> [RecordedRequest] {
        lock.withLock { recordedRequests }
    }
}
