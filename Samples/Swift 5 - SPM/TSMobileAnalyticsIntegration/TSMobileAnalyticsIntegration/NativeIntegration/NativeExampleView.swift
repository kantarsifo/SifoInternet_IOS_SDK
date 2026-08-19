//
//  NativeExampleView.swift
//  NativeIntegration
//
//  Created by Karl Söderberg on 2023-10-04.
//  Copyright © 2023 TNS Sifo AB. All rights reserved.
//

import SwiftUI
import TSMobileAnalytics

struct ExampleView: View {
    @ObservedObject var diagnostics: TestDiagnosticsStore

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    dashboard
                }
            } else {
                NavigationView {
                    dashboard
                }
            }
        }
    }

    private var dashboard: some View {
        List {
            Section(header: Text("SDK")) {
                diagnosticValue(label: "SDK version", value: diagnostics.sdkVersion)
                diagnosticValue(label: "Configuration", value: diagnostics.isConfigured ? "Ready" : "Missing CPID")
            }

            Section(header: Text("Actions")) {
                Button(action: sendTag) {
                    Label("Send test tag", systemImage: "paperplane")
                }
                .disabled(!diagnostics.isConfigured)

                NavigationLink(destination: WebViewTestView()) {
                    Label("Open WebView test", systemImage: "globe")
                }
            }

            Section(header: Text("Diagnostic log")) {
                if diagnostics.entries.isEmpty {
                    Text("Waiting for SDK diagnostics…")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(diagnostics.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.message)
                            Text(entry.timestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .navigationTitle("SDK test")
    }

    private func sendTag() {
        guard diagnostics.isConfigured else { return }

        TSMobileAnalytics.sendTag(
            withCategories: ["category-testios"],
            contentID: "123-contentID"
        ) { success, error in
            diagnostics.recordManualTagResult(success: success, error: error)
        }
    }

    private func diagnosticValue(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
