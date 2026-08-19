//
//  SampleAnalyticsConfiguration.swift
//  NativeIntegration
//

import Foundation

enum SampleAnalyticsConfiguration {
    /// Replace this placeholder with the 32-character CPID for the test environment.
    static let cpid = "REPLACE_WITH_TEST_CPID"

    static let applicationName = "Sample app"
    static let keychainAccessGroup = "mo.dyna.TSMobileAnalyticsIntegration"

    static var isConfigured: Bool {
        cpid.count == 32 && cpid != "REPLACE_WITH_TEST_CPID"
    }
}
