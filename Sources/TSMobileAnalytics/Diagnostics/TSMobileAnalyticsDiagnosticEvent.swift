//
//  TSMobileAnalyticsDiagnosticEvent.swift
//  TSMobileAnalytics
//
//  Created by OpenAI on 2026-08-19.
//

import Foundation

/// A privacy-safe lifecycle event intended for opt-in integration diagnostics.
///
/// Diagnostic events never contain cookies, identifiers, CPIDs, content IDs, or request URLs.
public enum TSMobileAnalyticsDiagnosticEvent: Equatable {
    /// The SDK completed initialization.
    case initialized(sdkVersion: String)

    /// An automatic app-start tag was not scheduled because no stored cookie or
    /// installed panelist app was available to begin the sync flow.
    case appStartSkipped

    /// The SDK started sending the automatic app-start tag.
    case appStartAttempted

    /// The automatic app-start tag completed.
    case appStartCompleted(success: Bool, errorDescription: String?)
}
