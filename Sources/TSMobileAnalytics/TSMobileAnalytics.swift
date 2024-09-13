//
//  TSMobileAnalytics.swift
//  TSMobileAnalytics
//
//  Created by Andreas Lif on 2023-03-13.
//  Copyright © 2023 Kantar Sifo. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit

public final class TSMobileAnalytics {

    // TODO: Find a way to automate this.
    /// This needs to be updated when a new release is made.
    /// Swift Package version numbers are grabbed from the tags of the git repository.
    static let sdkVersion = "6.0.4"

    static var shared: TSMobileAnalytics?
    static let logger = ConsoleLogger()

    private let jsonDecoder = JSONDecoder()
    private let apiService = APIService()

    private let cpid: String
    private let applicationName: String
    private let trackingType: TrackingType
    private let isWebViewBased: Bool
    private let keychainAccessGroup: String?
    private let additionals: [String: String]
    private var keychainItemWrapper: KeychainItemWrapper?

    private var webViews = [WKWebView]()

    private let shouldSyncWithBackendFirst: Bool
    private let shouldUseJsonUrlSchemeSyncFormat: Bool

    private let deviceReference: String?
    private var userID: String?

    private var jsonFromAdditionalsDictionary: String? {
        jsonFromAdditionalsDictionary(additionals)
    }

    private var keychainUserId: String? {
        guard let data = keychainItemWrapper?.keychainData as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    private var isOldPanelUserInfoCached: Bool {
        Storage.shared.cookieString != nil
    }

    private var isSifoInternetAppInstalled: Bool {
        UIApplication.shared.canOpenURL(URL.panelistAppUrl)
    }

    private var isTrackingPanelistsOnly: Bool {
        trackingType == .TrackPanelistsOnly
    }

    /// Used to check if the host app can be re-opened from Sifo Internet app,
    /// once that has been opened.
    private var hostAppIncludesExpectedUrlScheme: Bool {
        UIApplication.shared.canOpenURL(URL.appUrl)
    }

    private var shouldSyncWithSifoInternetApp: Bool {
        
        if(!isSifoInternetAppInstalled){
            return false
        }
        
        if(Storage.shared.sdkVersion != Self.sdkVersion){
            return true
        }
        
        if (Storage.shared.cookieString?.isEmpty ?? true){
            return true
        }
        
        return false
    }

    /// Initializes an instance of `TSMobileAnalytics`.
    /// - Parameters:
    ///   - cpid: A customer specific id, provided by Kantar Sifo.
    ///   - applicationName: A unique name, chosen freely, which is used to identify the app.
    ///   - trackingType: A `TrackingType`, specifying one or more groups to track.
    ///   - isSystemIdentifierTrackingEnabled: A `Bool` indicating if system identifier tracking is enabled.
    ///   - isWebViewBased: A `Bool` indicating if the application is primarily based on HTML/JavaScript running in web views.
    ///   - keychainAccessGroup: An optional `String` used to share keychain items, e.g. `userId`,  across application from the same developer.
    ///   - additionals: An optional `String` to `String` `Dictionary`, used to sync any additional data with the panelist app.
    init(
        cpid: String,
        applicationName: String,
        trackingType: TrackingType,
        isSystemIdentifierTrackingEnabled: Bool,
        isWebViewBased: Bool,
        keychainAccessGroup: String?,
        additionals: [String: String] = [String: String]()
    ) {
        self.cpid = cpid
        self.applicationName = applicationName
        self.trackingType = trackingType
        self.isWebViewBased = isWebViewBased
        self.keychainAccessGroup = keychainAccessGroup
        self.additionals = additionals

        self.shouldSyncWithBackendFirst = additionals[Keys.shouldSyncWithBackendFirst] ?? "true" == StringBool.true.rawValue
        self.shouldUseJsonUrlSchemeSyncFormat = additionals[Keys.shouldUseJsonUrlSchemeSyncFormat] ?? "true" == StringBool.true.rawValue

        SDKIntegrationValidator.validate(applicationName: applicationName, cpid: cpid)

        IdentificationManager.shared.setIsSystemIdentifiterTrackingEnabled(isSystemIdentifierTrackingEnabled)

        self.deviceReference = Self.deviceReference(applicationName: applicationName)

        if let keychainAccessGroup {
            setUpKeychainItemWrapper(accessGroup: keychainAccessGroup)
        } else {
            setUpUserID()
        }

        handleCookieSync()

        logInitalization()
    }

    /// Initializes a `static` instance of `TSMobileAnalytics` called `shared`.
    /// - Parameters:
    ///   - cpid: A customer specific id, provided by Kantar Sifo.
    ///   - applicationName: A unique name, chosen freely, which is used to identify the app.
    ///   - trackingType: A `TrackingType`, specifying one or more groups to track.
    ///   - enableSystemIdentifierTracking: A `Bool` indicating if system identifier tracking is enabled.
    ///   - webViewBased: A `Bool` indicating if the application is primarily based on HTML/JavaScript running in web views.
    ///   - keychainAccessGroup: An optional `String` used to share keychain items, e.g. `userId`,  across application from the same developer.
    ///   - additionals: An optional `String` to `String` `Dictionary`, used to sync any additional data with the panelist app.
    public class func initialize(
        withCPID cpid: String,
        applicationName: String,
        trackingType: TrackingType,
        enableSystemIdentifierTracking: Bool,
        isWebViewBased: Bool = false,
        keychainAccessGroup: String?,
        additionals: [String: String] = [String: String]()
    ) {
        guard Self.shared == nil || isForcingReinitialization(additionals: additionals)
        else {
            Self.logger.log(
                message: "Framework has already been initialized.",
                verbosity: .warning)
            return
        }

        Self.shared = TSMobileAnalytics(
            cpid: cpid,
            applicationName: applicationName,
            trackingType: trackingType,
            isSystemIdentifierTrackingEnabled: enableSystemIdentifierTracking,
            isWebViewBased: isWebViewBased,
            keychainAccessGroup: keychainAccessGroup,
            additionals: additionals
        )
    }

    public static func setLogPrintsActivated(_ isEnabled: Bool, verbosiry: Verbosity = .debug) {
        guard isEnabled else { return }
        Self.logger.verbosity = verbosiry
    }

    public static func addWebView(_ webView: WKWebView) {
        Self.shared?.webViews.append(webView)
        Self.shared?.refreshCookies() {}
    }

    public static func removeWebView(_ webView: WKWebView) {
        if let index = Self.shared?.webViews.firstIndex(where: { $0 == webView }) {
            self.shared?.webViews.remove(at: index)
        } else {
            Self.logger.log(
                message: "Failed to remove web view.",
                verbosity: .warning)
        }
    }

    @discardableResult public static func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        if url.scheme?.lowercased() == Bundle.main.exchangeUrlScheme.lowercased() {
            DispatchQueue.main.async {
                Self.shared?.syncSourceAppWithFramework(form: url)
            }
        }

        return true
    }

    public static func sendTag(withCategories categories: [String], contentID: String? = nil, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let sharedInstance = Self.shared else {
            Self.logger.log(
                message: "Send tag failed: SDK has not been initialized.",
                verbosity: .error)
            return
        }

        guard !(sharedInstance.trackingType == .TrackPanelistsOnly && Storage.shared.cookieString == nil) else {
            Self.logger.log(
                message: "Send tag failed: Only tracking panelists and no cookies stored.",
                verbosity: .warning)
            return
        }

        sharedInstance.apiService.sendTag(
            sdkVersion: sdkVersion,
            categories: categories,
            contentID: contentID ?? .empty,
            reference: sharedInstance.deviceReference ?? .empty,
            cpid: sharedInstance.cpid,
            euid: sharedInstance.userID ?? sharedInstance.uuidString(),
            isTrackingPanelistsOnly: sharedInstance.isTrackingPanelistsOnly,
            isWebViewBased: sharedInstance.isWebViewBased,
            completion: completion
        )
    }

}

// MARK: - Private
private extension TSMobileAnalytics {

    static let devicePrefix: String? = {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return "APP_IPHONE_"
        case .pad:
            return "APP_IPAD_"
        default:
            return nil
        }
    }()

    static func isForcingReinitialization(additionals: [String: String]) -> Bool {
        additionals[Keys.isForcingReinitialization] == StringBool.true.rawValue
    }

    func jsonFromAdditionalsDictionary(_ additionals: [String: String]) -> String? {
        let adId = IdentificationManager.shared.advertisingIdentifier
        let vendorId = IdentificationManager.shared.vendorIdentifier

        let dictionary: [String: Any] = [
            .appScheme: Bundle.main.exchangeUrlScheme,
            .keyValues: [
                String.keyValueAdId: adId?.uuidString,
                String.keyValueVendorId: vendorId?.uuidString
            ],
            .additionalKeyValues: additionals
        ]

        guard JSONSerialization.isValidJSONObject(dictionary),
              let jsonData = try? JSONSerialization.data(withJSONObject: dictionary)
        else {
            Self.logger.log(
                message: "Failed to create JSON data.",
                verbosity: .error)

            return nil
        }

        return String(data: jsonData, encoding: .utf8)
    }

    func handleCookieSync() {
        guard isOldPanelUserInfoCached || isSifoInternetAppInstalled
        else { return }

        if (IdentificationManager.shared.isSystemIdentifierTrackingEnabled && shouldSyncWithBackendFirst) {
            syncCookiesWithBackend()
        } else {
            if hostAppIncludesExpectedUrlScheme && shouldSyncWithSifoInternetApp {
                syncTokenWithSifoInternetApp(additionals: additionals)
            } else {
                refreshCookies() { self.sendTagWithAppStart() }
            }
        }
    }

    func syncCookiesWithBackend() {
        apiService.sync(
            sdkVersion: Self.sdkVersion,
            appName: applicationName,
            json: jsonFromAdditionalsDictionary ?? .empty
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                Self.logger.log(
                    multipleLines: [
                        "Failed to sync with backend.",
                        "\(error)"],
                    verbosity: .error)
                onBackendSyncError()
            case .success(let response):
                Self.logger.log(
                    multipleLines: [
                        "Response received:",
                        String(data: response, encoding: .utf8) ?? .empty],
                    verbosity: .debug)
                do {
                    let syncResponse = try self.jsonDecoder.decode(SyncResponse.self, from: response)
                    
                    try self.updateCookieString(from: syncResponse.cookies)
                    self.refreshCookies { self.sendTagWithAppStart()}
                   
                    Self.logger.log(
                        message: "Successfully synced with backend.",
                        verbosity: .info)
                    
                } catch {
                    Self.logger.log(
                        multipleLines: [
                            "Failed to verify sync response.",
                            error.localizedDescription],
                        verbosity: .error)
                    onBackendSyncError()
                }
            }
        }
    }
    
    private func onBackendSyncError(){
        // fallback to sync with panelist app
        if self.shouldSyncWithSifoInternetApp {
            syncTokenWithSifoInternetApp(additionals: additionals)
        } else {
            self.refreshCookies() { self.sendTagWithAppStart() }
        }
    }
    
    func updateCookieString(from cookies:[Cookie]) throws {
        guard let urlEncoded = try cookies.urlEncoded() else {
            Self.logger.log(message: "Unable to update cookies", verbosity: .error)
            return
        }
        Storage.shared.cookieString = urlEncoded
    }

    func updateCookieString(_ cookieString: String) {
        Storage.shared.cookieString = cookieString
    }

    func refreshCookies(completion: @escaping () -> Void) {
        guard let cookieString = Storage.shared.cookieString,
              let cookieDictionaries = JSONManager.parseURLEncodedJSON(cookieString)
        else { return }

        var cookies = cookieDictionaries.cookies()
        cookies.append(contentsOf: settingsCookies())

        CookieManager.setCookies(cookies, completion: completion)
        setLocalStorage(with: cookies)
    }

    func settingsCookies() -> [HTTPCookie] {
        var cookies = [HTTPCookie]()

        if let trackingTypeCookie { cookies.append(trackingTypeCookie) }
        if let webViewBasedCookie { cookies.append(webViewBasedCookie) }
        if let sdkVersionCookie { cookies.append(sdkVersionCookie) }
        if let appVersionCookie { cookies.append(appVersionCookie) }
        if let configCookie { cookies.append(configCookie) }

        return cookies
    }

    func setLocalStorage(with cookies: [HTTPCookie]) {
        for webView in webViews {
            webView.setLocalStorage(with: cookies)
        }
    }

    func sendTagWithAppStart() {
        Self.sendTag(withCategories: [.appStart])
    }

    func setUpUserID() {
        self.userID = uuidString()
    }

    func uuidString() -> String {
        guard let uuidString = Storage.shared.uuidString else {
            let uuidString = UUID().uuidString
            Storage.shared.uuidString = uuidString
            return uuidString
        }
        return uuidString
    }

    func setUpKeychainItemWrapper(accessGroup: String) {
        let formattedAccessGroup = Self.formattedAccessGroup(fromAccessGroup: accessGroup)

        keychainItemWrapper = KeychainItemWrapper(identifier: String.userID,
                                                  accessGroup: formattedAccessGroup)

        if let uuidString = keychainUserId, !uuidString.isEmpty {
            setUpKeychainItems(identifier: uuidString,
                               accessGroup: formattedAccessGroup)
            self.userID = uuidString
        }
    }

    func setUpKeychainItems(identifier: String, accessGroup: String) {
        let uuidData = UUID().uuidString.data(using: .utf8)
        keychainItemWrapper?.setKeychainItems(
            accessGroup: accessGroup,
            securityClass: kSecClassGenericPassword,
            account: String.userID,
            service: String.serviceName,
            data: uuidData as CFData?
        )
    }

    func syncTokenWithSifoInternetApp(additionals: [String: String]) {
        guard (Storage.shared.nextSyncDate ?? .distantFuture) > .now else { return }

        var urlString: String = URL.panelistAppString

        if shouldUseJsonUrlSchemeSyncFormat,
           let jsonFromAdditionalsDictionary {
            urlString.append(jsonFromAdditionalsDictionary)
        } else {
            urlString.append(Bundle.main.exchangeUrlScheme)
        }

        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url)
        else {
            Self.logger.log(
                message: "Failed to sync token with Sifo Internet app.",
                verbosity: .error)
            return
        }

        UIApplication.shared.open(url)
    }

    static func deviceReference(applicationName: String) -> String? {
        guard let devicePrefix = Self.devicePrefix else {
            Self.logger.log(message: "Unknown device type.", verbosity: .warning)
            return nil
        }
        return devicePrefix + applicationName
    }

    static func formattedAccessGroup(fromAccessGroup accessGroup: String) -> String {
        (KeychainItemWrapper.bundleSeedID() ?? .empty) + accessGroup
    }

    func syncSourceAppWithFramework(form url: URL) {
        updateSDKVersion()

        guard let cookieString = url.resourceSpecifier,
              !cookieString.isEmpty
        else {
            setNextSyncDate()
            return
        }

        updateCookieString(cookieString)
        refreshCookies {
            self.sendTagWithAppStart()
        }

        Self.logger.log(
            message: "Synced with panelist app.",
            verbosity: .info)
    }

    func setNextSyncDate() {
        let numberOfWeeks = Storage.shared.nextSyncDate == nil ? 2 : 12
        Storage.shared.nextSyncDate = .now.advancedBy(numberOfWeeks: numberOfWeeks)
    }

    func updateSDKVersion() {
        Storage.shared.sdkVersion = Self.sdkVersion
    }

    func logInitalization() {
        Self.logger.log(
            multipleLines: [
                "Framework initialized",
                "CPID: \(cpid)",
                "App name: \(applicationName)"
            ],
            verbosity: .info)
    }
}

// MARK: - Cookies

private extension TSMobileAnalytics {

    var trackPanelistOnlyString: String {
        trackingType == .TrackPanelistsOnly ? StringBool.true.rawValue : StringBool.false.rawValue
    }

    var isWebViewBasedString: String {
        isWebViewBased ? StringBool.true.rawValue : StringBool.false.rawValue
    }

    var trackingTypeCookie: HTTPCookie? {
        HTTPCookie(domain: .settingsCookieDomain,
                   name: CookieKeys.trackPanelistOnly,
                   value: trackPanelistOnlyString)
    }

    var webViewBasedCookie: HTTPCookie? {
        HTTPCookie(domain: .settingsCookieDomain,
                   name: CookieKeys.isWebViewBased,
                   value: isWebViewBasedString)
    }

    var sdkVersionCookie: HTTPCookie? {
        HTTPCookie(domain: .settingsCookieDomain,
                   name: CookieKeys.sdkVersion,
                   value: Self.sdkVersion)
    }

    var appVersionCookie: HTTPCookie? {
        HTTPCookie(domain: .settingsCookieDomain,
                   name: CookieKeys.appVersion,
                   value: Bundle.main.appVersionString)
    }

    var configCookie: HTTPCookie? {
        HTTPCookie(
            domain: .settingsCookieDomain,
            name: CookieKeys.sifoConfig,
            value: (CookieKeys.trackPanelistOnly + .equals + trackPanelistOnlyString + .ampersand
                    + CookieKeys.isWebViewBased + .equals + isWebViewBasedString))
    }
}

// MARK: - Strings

private extension String {
    static let userID = "tns-sifo-device-id"
    static let serviceName = "tnssifo-mobile-tagging"
    static let appScheme = "appScheme"
    static let keyValues = "keyValues"
    static let additionalKeyValues = "additionalKeyValues"
    static let keyValueAdId = "a0"
    static let keyValueVendorId = "a1"
    static let settingsCookieDomain = ".research-int.se"
    static let appStart = "appstart"
}

// MARK: - Keys
private struct Keys {
    static let isForcingReinitialization = "se.tns-sifo.forceReinitialize"
    static let shouldSyncWithBackendFirst = "se.tns-sifo.syncWithBackendFirst"
    static let shouldUseJsonUrlSchemeSyncFormat = "se.tns-sifo.useJsonUrlSchemeSyncFormat"
    static let cookieInfo = "CookieInfos"
}

private struct CookieKeys {
    static let trackPanelistOnly = "trackPanelistOnly"
    static let isWebViewBased = "isWebViewBased"
    static let sdkVersion = "sdkVersion"
    static let appVersion = "appVersion"
    static let sifoConfig = "sifo_config"
}
