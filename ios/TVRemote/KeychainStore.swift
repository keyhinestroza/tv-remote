import Foundation
import Security

/// Acceso mínimo al Keychain para guardar el token que entrega el TV.
enum KeychainStore {
    private static let service = "com.key.tvremote.token"

    /// Guarda (o reemplaza) el token asociado a un host.
    /// - Returns: false si el Keychain rechazó la escritura (p. ej. app sin firmar).
    @discardableResult
    static func save(token: String, host: String) -> Bool {
        delete(host: host)
        var query = baseQuery(host: host)
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Devuelve el token guardado para un host, si existe.
    static func token(host: String) -> String? {
        var query = baseQuery(host: host)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Borra el token de un host (obliga a autorizar de nuevo en el TV).
    static func delete(host: String) {
        SecItemDelete(baseQuery(host: host) as CFDictionary)
    }

    private static func baseQuery(host: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
        ]
    }
}
