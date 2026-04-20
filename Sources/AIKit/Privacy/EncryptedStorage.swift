import Foundation
import CryptoKit
import Security

public enum EncryptedStorage {
    public static func writeEncrypted(_ data: Data, to url: URL, keyTag: String) throws {
        let key = try obtainKey(tag: keyTag)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw AIError.unknown("AES.GCM combined is nil")
        }
        try combined.write(to: url, options: .atomic)
    }

    public static func readEncrypted(_ url: URL, keyTag: String) throws -> Data {
        let key = try obtainKey(tag: keyTag)
        let combined = try Data(contentsOf: url)
        let sealed = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealed, using: key)
    }

    public static func obtainKey(tag: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecReturnData as String: true
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        if status == errSecSuccess, let data = out as? Data {
            return SymmetricKey(data: data)
        }
        let new = SymmetricKey(size: .bits256)
        let keyData = new.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            throw AIError.unknown("Keychain add failed: \(addStatus)")
        }
        return new
    }

    public static func deleteKey(tag: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag
        ]
        SecItemDelete(query as CFDictionary)
    }
}
