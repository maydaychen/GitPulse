import Foundation
import Security

public struct StoredCredentials: Codable, Sendable, Equatable {
    public var patToken: String
    public var customHeaders: [String: String]

    public init(patToken: String, customHeaders: [String: String] = [:]) {
        self.patToken = patToken
        self.customHeaders = customHeaders
    }
}

public protocol CredentialStore: Sendable {
    func saveCredentials(_ credentials: StoredCredentials, forProfileID profileID: String) throws
    func loadCredentials(forProfileID profileID: String) -> StoredCredentials?
    func deleteCredentials(forProfileID profileID: String)
}

public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String
    private let accessGroup: String?

    public init(service: String = "com.maydaychen.teapulse.pat", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func saveCredentials(_ credentials: StoredCredentials, forProfileID profileID: String) throws {
        let data = try JSONEncoder().encode(credentials)
        var query = baseQuery(profileID: profileID)
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else {
            throw GiteaClientError.networkFailure("Keychain 更新失败 (\(updated))")
        }
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw GiteaClientError.networkFailure("Keychain 写入失败 (\(status))")
        }
    }

    public func loadCredentials(forProfileID profileID: String) -> StoredCredentials? {
        var query = baseQuery(profileID: profileID)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(StoredCredentials.self, from: data)
    }

    public func deleteCredentials(forProfileID profileID: String) {
        let query = baseQuery(profileID: profileID)
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(profileID: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: StoredCredentials] = [:]

    public init() {}

    public func saveCredentials(_ credentials: StoredCredentials, forProfileID profileID: String) throws {
        lock.withLock {
            storage[profileID] = credentials
        }
    }

    public func loadCredentials(forProfileID profileID: String) -> StoredCredentials? {
        lock.withLock {
            storage[profileID]
        }
    }

    public func deleteCredentials(forProfileID profileID: String) {
        _ = lock.withLock {
            storage.removeValue(forKey: profileID)
        }
    }
}
