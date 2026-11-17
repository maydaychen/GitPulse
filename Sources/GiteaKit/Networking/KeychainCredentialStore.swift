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
    public static let defaultSharedAccessGroup = "group.com.maydaychen.teapulse"

    private let service: String
    private let accessGroup: String?
    private let allowLegacyFallback: Bool

    public init(
        service: String = "com.maydaychen.teapulse.pat",
        accessGroup: String? = KeychainCredentialStore.defaultSharedAccessGroup,
        allowLegacyFallback: Bool = true
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.allowLegacyFallback = allowLegacyFallback
    }

    public func saveCredentials(_ credentials: StoredCredentials, forProfileID profileID: String) throws {
        let data = try JSONEncoder().encode(credentials)
        if let accessGroup, !accessGroup.isEmpty {
            let sharedStatus = upsert(data: data, profileID: profileID, accessGroup: accessGroup)
            if sharedStatus == errSecSuccess {
                if allowLegacyFallback {
                    _ = upsert(data: data, profileID: profileID, accessGroup: nil)
                }
                return
            }
            if !allowLegacyFallback {
                throw GiteaClientError.networkFailure("Keychain 共享组写入失败 (\(sharedStatus))")
            }
        }

        let fallbackStatus = upsert(data: data, profileID: profileID, accessGroup: nil)
        guard fallbackStatus == errSecSuccess else {
            throw GiteaClientError.networkFailure("Keychain 写入失败 (\(fallbackStatus))")
        }
    }

    public func loadCredentials(forProfileID profileID: String) -> StoredCredentials? {
        if let accessGroup, !accessGroup.isEmpty,
           let shared = read(profileID: profileID, accessGroup: accessGroup) {
            return shared
        }
        guard allowLegacyFallback else { return nil }
        return read(profileID: profileID, accessGroup: nil)
    }

    public func deleteCredentials(forProfileID profileID: String) {
        if let accessGroup, !accessGroup.isEmpty {
            SecItemDelete(baseQuery(profileID: profileID, accessGroup: accessGroup) as CFDictionary)
        }
        if allowLegacyFallback {
            SecItemDelete(baseQuery(profileID: profileID, accessGroup: nil) as CFDictionary)
        }
    }

    private func upsert(data: Data, profileID: String, accessGroup: String?) -> OSStatus {
        var query = baseQuery(profileID: profileID, accessGroup: accessGroup)
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated != errSecItemNotFound {
            return updated
        }
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil)
    }

    private func read(profileID: String, accessGroup: String?) -> StoredCredentials? {
        var query = baseQuery(profileID: profileID, accessGroup: accessGroup)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(StoredCredentials.self, from: data)
    }

    private func baseQuery(profileID: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
            #if os(macOS)
            query[kSecUseDataProtectionKeychain as String] = kCFBooleanTrue
            #endif
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
