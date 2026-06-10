//
//  KeychainItemWrapper.swift
//  TSMobileAnalytics
//
//  Created by Andreas Lif on 2023-03-16.
//  Copyright © 2023 Kantar Sifo. All rights reserved.
//

import Foundation

protocol KeychainClient {
    func add(_ attributes: [CFString: Any]) -> OSStatus
    func copyMatching(_ query: [CFString: Any], result: inout CFTypeRef?) -> OSStatus
    func update(_ query: [CFString: Any], attributesToUpdate: [CFString: Any]) -> OSStatus
}

struct SecurityKeychainClient: KeychainClient {
    func add(_ attributes: [CFString: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func copyMatching(_ query: [CFString: Any], result: inout CFTypeRef?) -> OSStatus {
        SecItemCopyMatching(query as CFDictionary, &result)
    }

    func update(_ query: [CFString: Any], attributesToUpdate: [CFString: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
    }
}

final class KeychainItemWrapper {
    private let identifier: String
    private let accessGroup: String
    private let account: String
    private let service: String
    private let keychainClient: KeychainClient

    private(set) var keychainData: Data?

    init(
        identifier: String,
        accessGroup: String,
        account: String,
        service: String,
        keychainClient: KeychainClient = SecurityKeychainClient()
    ) {
        self.identifier = identifier
        self.accessGroup = accessGroup
        self.account = account
        self.service = service
        self.keychainClient = keychainClient

        reload()
    }

    func setKeychainData(_ data: Data) {
        let query = itemQuery(returnData: false)
        var result: CFTypeRef?
        let status = keychainClient.copyMatching(query, result: &result)

        switch status {
        case errSecSuccess:
            let updateStatus = keychainClient.update(query, attributesToUpdate: [
                kSecValueData: data
            ])

            guard updateStatus == errSecSuccess else {
                TSMobileAnalytics.logger.log(
                    message: "Failed to update keychain item.",
                    verbosity: .error)
                return
            }
        case errSecItemNotFound:
            var attributes = itemQuery(returnData: false)
            attributes[kSecValueData] = data

            let addStatus = keychainClient.add(attributes)
            guard addStatus == errSecSuccess else {
                TSMobileAnalytics.logger.log(
                    message: "Failed to add keychain item.",
                    verbosity: .error)
                return
            }
        default:
            TSMobileAnalytics.logger.log(
                message: "Unexpected status code while writing keychain item: \(status).",
                verbosity: .error)
            return
        }

        keychainData = data
    }

    func reload() {
        let query = itemQuery(returnData: true)
        var result: CFTypeRef?
        let status = keychainClient.copyMatching(query, result: &result)

        switch status {
        case errSecSuccess:
            keychainData = result as? Data
        case errSecItemNotFound:
            keychainData = nil
        default:
            keychainData = nil
            TSMobileAnalytics.logger.log(
                message: "Failed to retrieve keychain item.",
                verbosity: .error)
        }
    }

    static func bundleSeedID() -> String? {
        var query = [CFString: Any]()
        query[kSecClass] = kSecClassGenericPassword
        query[kSecAttrAccount] = String.bundleSeedID
        query[kSecAttrService] = String.empty
        query[kSecReturnAttributes] = kCFBooleanTrue

        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            status = SecItemAdd(query as CFDictionary, &result)
        }

        guard status == errSecSuccess,
              let result = result as? [CFString: Any],
              let accessGroup = result[kSecAttrAccessGroup] as? String,
              let bundleSeedId = accessGroup.components(
                separatedBy: CharacterSet(charactersIn: .dot)).first
        else {
            TSMobileAnalytics.logger.log(
                message: "Failed to get bundle seed id.",
                verbosity: .error)
            return nil
        }

        return bundleSeedId
    }
}

private extension KeychainItemWrapper {
    func itemQuery(returnData: Bool) -> [CFString: Any] {
        var query = [CFString: Any]()
        query[kSecClass] = kSecClassGenericPassword
        query[kSecAttrGeneric] = identifier.data(using: .utf8)
        query[kSecAttrAccount] = account
        query[kSecAttrService] = service
        query[kSecMatchLimit] = kSecMatchLimitOne

#if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup] = accessGroup
#endif

        if returnData {
            query[kSecReturnData] = kCFBooleanTrue
        }

        return query
    }
}

private extension String {
    static let bundleSeedID = "bundleSeedID"
}
