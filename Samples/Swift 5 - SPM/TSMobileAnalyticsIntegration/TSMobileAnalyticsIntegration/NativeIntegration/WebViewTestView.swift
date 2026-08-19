//
//  WebViewTestView.swift
//  NativeIntegration
//

import SwiftUI
import WebKit
import TSMobileAnalytics

struct WebViewTestView: View {
    private let testURL = URL(string: "https://kantar-webview-test.queenslab-stockholm.workers.dev/")!

    var body: some View {
        SDKRegisteredWebView(url: testURL)
            .navigationTitle("WebView test")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct SDKRegisteredWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        TSMobileAnalytics.addWebView(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }

        context.coordinator.loadedURL = url
        webView.load(URLRequest(url: url))
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        TSMobileAnalytics.removeWebView(webView)
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
