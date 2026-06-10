//
//  APIService.swift
//  TSMobileAnalytics
//
//  Created by Andreas Lif on 2023-03-23.
//  Copyright © 2023 Kantar Sifo. All rights reserved.
//

import Foundation

protocol NetworkSession {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> NetworkDataTask
}

protocol NetworkDataTask {
    func resume()
}

extension URLSessionDataTask: NetworkDataTask {}

extension URLSession: NetworkSession {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> NetworkDataTask {
        let task: URLSessionDataTask = dataTask(with: request, completionHandler: completionHandler)
        return task
    }
}

final class APIService {
    private let session: NetworkSession

    init(session: NetworkSession = URLSession.shared) {
        self.session = session
    }

    public func sendTag(
        sdkVersion: String,
        categories: [String],
        contentID: String,
        reference: String,
        cpid: String,
        euid: String,
        isTrackingPanelistsOnly: Bool,
        isWebViewBased: Bool,
        completion: ((Bool, Error?) -> Void)? = nil
    ) {
        let categoryString = categories.slashSeparatedString()

        guard isValidCategoryString(categoryString) else {
            TSMobileAnalytics.logger.log(
                multipleLines: [
                    "Failed to send tag.",
                    SendTagError.combinedCategoriesTooLong.localizedDescription
                ],
                verbosity: .error)

            completion?(false, SendTagError.combinedCategoriesTooLong)

            return
        }

        guard isValidContentID(contentID) else {
            TSMobileAnalytics.logger.log(
                multipleLines: [
                    "Failed to send tag.",
                    SendTagError.contentIDTooLong.localizedDescription
                ],
                verbosity: .error)

            completion?(false, SendTagError.contentIDTooLong)

            return
        }

        let url = sendTagURL(
            cpid: cpid,
            userID: euid,
            categoryString: categoryString,
            contentID: contentID,
            appName: .application,
            reference: reference,
            isTrackingPanelistsOnly: isTrackingPanelistsOnly,
            isWebViewBased: isWebViewBased,
            appVersion: Bundle.main.appVersionString,
            sdkVersion: sdkVersion
        )

        TSMobileAnalytics.logger.log(
            multipleLines: [
                "Prepared tag request.",
                redactedQueryLog(from: url)
            ],
            verbosity: .debug)

        let urlRequest = URLRequest(url: url)

        performRequest(urlRequest) { response in
            switch response {
            case .success(_):
                TSMobileAnalytics.logger.log(
                    message: "Successfully sent tag.",
                    verbosity: .info)

                completion?(true, nil)

            case .failure(let error):
                TSMobileAnalytics.logger.log(
                    multipleLines: [
                        "Failed to send tag.",
                        error.localizedDescription
                    ],
                    verbosity: .error)

                completion?(false, error)
            }
        }
    }

    func sync(sdkVersion: String, appName: String, json: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let url = syncURL(
            sdkVersion: sdkVersion,
            appName: appName,
            json: json)
        let urlRequest = URLRequest(url: url)

        performRequest(urlRequest, completion: completion)
    }

    func sendTagURL(
        cpid: String,
        userID: String,
        categoryString: String,
        contentID: String,
        appName: String,
        reference: String,
        isTrackingPanelistsOnly: Bool,
        isWebViewBased: Bool,
        appVersion: String,
        sdkVersion: String
    ) -> URL {

        let parameters: KeyValuePairs<String, String> = [
            .siteId : cpid,
            .appClientId : userID,
            .cp : categoryString,
            .appId : contentID,
            .appName : appName,
            .appRef : reference,
            .trackingPanelistsOnly : (
                isTrackingPanelistsOnly
                ? StringBool.true.rawValue
                : StringBool.false.rawValue),
            .isWebViewBased : (
                isWebViewBased
                ? StringBool.true.rawValue
                : StringBool.false.rawValue),
            .appVersion : appVersion,
            .sessionSDK : .sdkVersionPrefix + sdkVersion
        ]

        return url(.trafficGatewayBaseURL, withParameters: parameters)
    }

    func syncURL(sdkVersion: String, appName: String, json: String) -> URL {
        let parameters: KeyValuePairs<String, String> = [
            .sdkVersion : sdkVersion,
            .appName.lowercased() : appName,
            .frameworkInfo : json
        ]

        return url(.sifoBaseURL, withParameters: parameters)
    }
}

extension String {
    func urlEncoded() -> String {
        guard let encoded = self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            TSMobileAnalytics.logger.log(
                message: "Failed to add percent encoding to URL",
                verbosity: .error)
            return .empty
        }

        return encoded
    }

    func queryEncoded() -> String {
        guard let encoded = self.addingPercentEncoding(withAllowedCharacters: .urlQueryExtendedAllowed)
        else {
            TSMobileAnalytics.logger.log(
                message: "Failed to add percent encoding to URL",
                verbosity: .error)
            return .empty
        }

        return encoded
    }
}

extension CharacterSet{
    static let urlQueryExtendedAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: String.slash))
}

// MARK: - Private

private extension APIService {
    func performRequest(_ request: URLRequest , completion: @escaping (Result<Data, Error>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let response = response as? HTTPURLResponse,
                  response.statusCode >= 200,
                  response.statusCode < 300
            else {
                completion(.failure(APIError.badResponse((response as? HTTPURLResponse)?.statusCode)))
                return
            }
            guard let data else {
                completion(.failure(APIError.noData))
                return
            }
            completion(.success(data))
        }.resume()
    }

    func isValidCategoryString(_ categoryString: String) -> Bool {
        categoryString.count <= .categoryMaxLength
    }

    func isValidContentID(_ contentID: String) -> Bool {
        contentID.count <= .contentIDMaxLength
    }

    func url(_ baseUrl: URL, withParameters parameters: KeyValuePairs<String, String>) -> URL {
        guard var urlComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)
        else { return baseUrl }

        urlComponents.queryItems = parameters.map { key, value in
            URLQueryItem(name: key, value: value)
        }

        return urlComponents.url ?? baseUrl
    }

    func redactedQueryLog(from url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            return url.absoluteString
        }

        components.queryItems = queryItems.map { item in
            if Self.redactedQueryNames.contains(item.name) {
                return URLQueryItem(name: item.name, value: "[REDACTED]")
            }

            return item
        }

        return components.url?.absoluteString ?? url.absoluteString
    }
}

private extension String {
    static let panelistInfo = "/GetPanelistInfo"

    static let sdkVersion = "sdkversion"
    static let frameworkInfo = "SifoAppFrameworkInfo"

    static let siteId = "siteId"
    static let appClientId = "appClientId"
    static let cp = "cp"
    static let appId = "appId"
    static let appName = "appName"
    static let appRef = "appRef"
    static let trackingPanelistsOnly = "TrackPanelistsOnly"
    static let isWebViewBased = "IsWebViewBased"
    static let appVersion = "appVersion"
    static let sessionSDK = "session"

    static let sdkVersionPrefix = "sdk_"
    static let application = "application"
}

private extension Int {
    static let categoryMaxLength = 255
    static let contentIDMaxLength = 255
}

private extension APIService {
    static let redactedQueryNames: Set<String> = [
        .appClientId,
        .appRef
    ]
}
