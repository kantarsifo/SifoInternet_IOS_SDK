//
//  WKWebView+.swift
//  TSMobileAnalytics
//
//  Created by Andreas Lif on 2023-03-30.
//  Copyright © 2023 Kantar Sifo. All rights reserved.
//

import Foundation
import WebKit

extension WKWebView {
    func setLocalStorage(with cookies: [HTTPCookie]) {
        let cookieDictionary = Dictionary(
            uniqueKeysWithValues: cookies.map { ($0.name + .raised + $0.domain, $0.value) })

        let javaScript = cookieDictionary.reduce(into: String.empty) {
            $0 += javaScriptSubstring(key: $1.key, value: $1.value)
        }

        evaluateJavaScript(javaScript, withRetryAttempts: .localStorageRetryLimit)
    }
}

// MARK: - Private

private extension WKWebView {
    func javaScriptSubstring(key: String, value: String) -> String {
        "localStorage.setItem(\"\(key)\", \"\(value)\");\n"
    }

    /// Calls `evaluateJavaScript(_:)` with one second intervals until it succeeds.
    ///
    /// The function `evaluateJavaScript(_:)` fails if `self` has not finished navigating.
    ///
    /// This still uses retry-based coordination instead of a navigation delegate,
    /// but keeps retries bounded so the SDK does not keep polling indefinitely.
    ///
    /// - Parameters:
    ///   - javaScript: The java script to evaluate.
    ///   - retryMax: The maximum number of retry attempts.
    ///   - currentCount: The current retry count, recursively incremented (optional).
    func evaluateJavaScript(_ javaScript: String, withRetryAttempts maxCount: Int, currentCount: Int = 0) {
        DispatchQueue.main.async {
            self.evaluateJavaScript(javaScript) { [weak self] _, error in
                guard let self else { return }

                if let error {
                    TSMobileAnalytics.logger.log(
                        multipleLines: [
                            "Failed to evaluate java script",
                            "Retry count: \(currentCount) / \(maxCount)",
                            "\(error)"
                        ],
                        verbosity: .debug)
                    if currentCount < maxCount {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.evaluateJavaScript(javaScript, withRetryAttempts: maxCount, currentCount: currentCount + 1)
                        }
                    }
                }
            }
        }
    }
}

private extension Int {
    static let localStorageRetryLimit = 10
}
