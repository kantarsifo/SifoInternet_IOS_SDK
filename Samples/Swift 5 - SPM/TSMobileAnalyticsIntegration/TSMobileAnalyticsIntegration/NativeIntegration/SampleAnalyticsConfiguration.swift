//
//  SampleAnalyticsConfiguration.swift
//  NativeIntegration
//

import Foundation

enum SampleAnalyticsConfiguration {
    /// Replace this placeholder with the 32-character CPID for the test environment.
    static let cpid = "f53c7a3d013d4b89a1c1e697dc724467"

    static let applicationName = "testApp-queenslab"
    static let keychainAccessGroup = "mo.dyna.TSMobileAnalyticsIntegration"

    static var isConfigured: Bool {
        cpid.count == 32 && cpid != "REPLACE_WITH_TEST_CPID"
    }
}
