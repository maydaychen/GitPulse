import Foundation

public enum GiteaURLBuilder {
    public static func apiURL(
        baseURLString: String,
        endpointPath: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        try buildURL(
            baseURLString: baseURLString,
            prefix: "/api/v1",
            endpointPath: endpointPath,
            queryItems: queryItems
        )
    }

    public static func healthzURL(baseURLString: String) throws -> URL {
        try buildURL(
            baseURLString: baseURLString,
            prefix: "",
            endpointPath: "/api/healthz",
            queryItems: []
        )
    }

    public static func buildURL(
        baseURLString: String,
        prefix: String,
        endpointPath: String,
        queryItems: [URLQueryItem]
    ) throws -> URL {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil else {
            throw GiteaClientError.invalidBaseURL(baseURLString)
        }

        let basePath = components.percentEncodedPath.hasSuffix("/")
            ? String(components.percentEncodedPath.dropLast())
            : components.percentEncodedPath
        let normalizedPrefix = prefix.isEmpty ? "" : (prefix.hasPrefix("/") ? prefix : "/\(prefix)")
        let normalizedEndpoint = endpointPath.hasPrefix("/") ? endpointPath : "/\(endpointPath)"
        let allowedPath = CharacterSet.urlPathAllowed.union(CharacterSet(charactersIn: "%"))
        guard normalizedEndpoint.removingPercentEncoding != nil,
              let encodedEndpoint = normalizedEndpoint.addingPercentEncoding(withAllowedCharacters: allowedPath) else {
            throw GiteaClientError.networkFailure("API 路径编码无效")
        }
        components.percentEncodedPath = "\(basePath)\(normalizedPrefix)\(encodedEndpoint)"
        if !queryItems.isEmpty {
            var merged = components.queryItems ?? []
            merged.append(contentsOf: queryItems)
            components.queryItems = merged
        }
        guard let url = components.url else {
            throw GiteaClientError.invalidBaseURL(baseURLString)
        }
        return url
    }

    public static func encodedSegment(_ raw: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%?#"))
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? raw
    }

    public static func overriddenCloneHTTPS(
        repoFullName: String,
        proxyBaseURL: String
    ) -> String {
        guard var components = URLComponents(string: proxyBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return proxyBaseURL
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = "\(basePath)/\(repoFullName).git"
        components.query = nil
        components.fragment = nil
        return components.url?.absoluteString ?? proxyBaseURL
    }

    public static func overriddenCloneSSH(
        repoFullName: String,
        host: String,
        sshPort: Int?
    ) -> String {
        if let sshPort, sshPort != 22 {
            return "ssh://git@\(host):\(sshPort)/\(repoFullName).git"
        }
        return "git@\(host):\(repoFullName).git"
    }
}
