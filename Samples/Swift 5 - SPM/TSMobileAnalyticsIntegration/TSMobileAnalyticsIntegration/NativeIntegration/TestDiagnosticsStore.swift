//
//  TestDiagnosticsStore.swift
//  NativeIntegration
//

import Combine
import Foundation
import TSMobileAnalytics

final class TestDiagnosticsStore: ObservableObject {
    @Published private(set) var entries: [DiagnosticLogEntry]

    let isConfigured: Bool
    let sdkVersion = TSMobileAnalytics.sdkVersion

    init(isConfigured: Bool) {
        self.isConfigured = isConfigured
        self.entries = isConfigured
            ? []
            : [DiagnosticLogEntry(message: "SDK configuration missing. Add a 32-character test CPID in SampleAnalyticsConfiguration.")]
    }

    func record(_ event: TSMobileAnalyticsDiagnosticEvent) {
        let message: String

        switch event {
        case let .initialized(sdkVersion):
            message = "SDK initialized (version \(sdkVersion))."
        case .appStartSkipped:
            message = "App-start was skipped because no stored cookie or panelist app was available."
        case .appStartAttempted:
            message = "App-start request started."
        case let .appStartCompleted(success, errorDescription):
            message = success
                ? "App-start request succeeded."
                : "App-start request failed: \(errorDescription ?? "Unknown error")."
        }

        append(message)
    }

    func recordManualTagResult(success: Bool, error: Error?) {
        let message = success
            ? "Manual test tag succeeded."
            : "Manual test tag failed: \(error?.localizedDescription ?? "Unknown error")."
        append(message)
    }

    private func append(_ message: String) {
        let appendEntry: () -> Void = { [weak self] in
            self?.entries.append(DiagnosticLogEntry(message: message))
        }

        if Thread.isMainThread {
            appendEntry()
        } else {
            DispatchQueue.main.async(execute: appendEntry)
        }
    }
}

struct DiagnosticLogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let message: String

    var timestamp: String {
        Self.timestampFormatter.string(from: date)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}
