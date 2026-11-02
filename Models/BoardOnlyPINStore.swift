import Foundation
import Security

enum BoardOnlyPINStore {
    enum PINError: LocalizedError {
        case invalidPIN
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidPIN: "Use 4 to 8 numbers for the PIN."
            case .keychain: "The PIN could not be saved on this device. Try again."
            }
        }
    }

    private static let service = "org.openvoice.aac.board-only-pin"

    static func isValid(_ pin: String) -> Bool {
        (4...8).contains(pin.count) && pin.utf8.allSatisfy { (48...57).contains($0) }
    }

    static func save(_ pin: String, for profileID: UUID) throws {
        guard isValid(pin) else { throw PINError.invalidPIN }
        let query = baseQuery(for: profileID)
        let value = Data(pin.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData: value] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData] = value
            attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw PINError.keychain(status) }
    }

    static func matches(_ pin: String, for profileID: UUID) -> Bool {
        guard let saved = read(for: profileID) else { return false }
        return saved == Data(pin.utf8)
    }

    static func hasPIN(for profileID: UUID) -> Bool {
        read(for: profileID) != nil
    }

    static func isMissing(for profileID: UUID) -> Bool {
        SecItemCopyMatching(baseQuery(for: profileID) as CFDictionary, nil) == errSecItemNotFound
    }

    static func delete(for profileID: UUID) {
        SecItemDelete(baseQuery(for: profileID) as CFDictionary)
    }

    private static func read(for profileID: UUID) -> Data? {
        var query = baseQuery(for: profileID)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func baseQuery(for profileID: UUID) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: profileID.uuidString]
    }
}

enum CalendarEditingPINStore {
    private static let service = "org.openvoice.aac.calendar-editing-pin"

    static func save(_ pin: String, for profileID: UUID) throws {
        guard BoardOnlyPINStore.isValid(pin) else { throw BoardOnlyPINStore.PINError.invalidPIN }
        let query = baseQuery(for: profileID)
        let value = Data(pin.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData: value] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData] = value
            attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw BoardOnlyPINStore.PINError.keychain(status) }
    }

    static func matches(_ pin: String, for profileID: UUID) -> Bool {
        guard let saved = read(for: profileID) else { return false }
        return saved == Data(pin.utf8)
    }

    static func isMissing(for profileID: UUID) -> Bool {
        SecItemCopyMatching(baseQuery(for: profileID) as CFDictionary, nil) == errSecItemNotFound
    }

    static func delete(for profileID: UUID) {
        SecItemDelete(baseQuery(for: profileID) as CFDictionary)
    }

    private static func read(for profileID: UUID) -> Data? {
        var query = baseQuery(for: profileID)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func baseQuery(for profileID: UUID) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: profileID.uuidString]
    }
}
