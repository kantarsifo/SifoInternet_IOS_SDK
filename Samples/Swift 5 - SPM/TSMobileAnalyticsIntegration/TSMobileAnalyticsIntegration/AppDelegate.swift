//
//  AppDelegate.swift
//  TSMobileAnalyticsIntegration
//
//  Created by Mohammad Najafi on 02/01/17.
//  Copyright © 2017 TNS Sifo AB. All rights reserved.
//

import UIKit
import SwiftUI
import TSMobileAnalytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let diagnostics = TestDiagnosticsStore(isConfigured: SampleAnalyticsConfiguration.isConfigured)
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        TSMobileAnalytics.setDiagnosticEventHandler { [weak diagnostics] event in
            diagnostics?.record(event)
        }

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.backgroundColor = UIColor.green
        self.window?.rootViewController = UIHostingController(rootView: ExampleView(diagnostics: diagnostics))
        self.window?.makeKeyAndVisible()
        
        //Initiate TSMobileAnalytics
        
        guard SampleAnalyticsConfiguration.isConfigured else { return true }

        TSMobileAnalytics.setLogPrintsActivated(true)
        TSMobileAnalytics.initialize(withCPID: SampleAnalyticsConfiguration.cpid,
                                     applicationName: SampleAnalyticsConfiguration.applicationName,
                                     trackingType: .TrackUsersAndPanelists, enableSystemIdentifierTracking: false,
                                     isWebViewBased: true,
                                     keychainAccessGroup: SampleAnalyticsConfiguration.keychainAccessGroup)
        
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return TSMobileAnalytics.application(app, open: url, options: options)
    }
}
