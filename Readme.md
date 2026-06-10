# Kantar Sifo Mobile Analytics SDK for iOS
This framework will enable your organisation to do mobile analytics and track user behaviour in your apps. 
It is only usable if your organisations has a mobile analytics account at Kantar Sifo: 

https://www.kantarsifo.se/kontakt. 

It is currently limited to Swedish customers only.

---
This framework is also available as a zip for manual installation, if you don't want to use cocoapods:   
https://github.com/kantarsifo/SifoInternetSDK 

This instruction assumes you have Cocoapods installed and are familiar with it.
Otherwise check instructions here: https://cocoapods.org/

You also need to have the 'Sifo Internet' panelist app installed on your test device. The 'Sifo Internet' app holds your Sifo ID details. Otherwise look here: https://apps.apple.com/se/app/sifo-internet/id1015394138

## Background

This framework tracks a user by making a formatted url call ('SendTag') with a cookie to a backend. Registered users are identified via a Sifo account and a UUID in the keychain (or NSUserDefaults if you don't want cross-app UUID sharing). The backend recognises the user via the cookie and the resource is tracked by the url. There a two types of users: Anonymous users and Orvesto panelists, who has opt-ed in to be tracked and is using a separat panelist app, called 'Sifo Internet'. It's optional to track all users or only panelist users.

This framework will open the 'Sifo Internet' app at first launch, if installed. If the 'Sifo Internet' app is configured correctly, then the 'Sifo Internet' app will in turn open your app almost directly, with a cookie in the app url. This cookie will be stored by the framework. It will also create a UUID in the keychain/NSUserDefaults. This UUID can be shared among your apps using a shared keychain or NSUserDefaults. After a successfull initialisation, the framework is ready to send your tracking tags to the analytics backend. You can track these tags using your tools obtained from Kantar Sifo upon registration.

To make this work, there a few things needed:
1. Allow your app to open the 'Sifo Internet' app in Info.plist
2. Add a shared keychain id to an Entitlements file (Optional)
3. Add the code below to integrate framework
4. Add SendTags according to your tracking needs

## Permissions

What permissions does the Sifo SDK require?

The Sifo SDK is happy with whatever permissions your app uses.

* If your app requests access to IDFA through the App Tracking Transparency framework the Sifo SDK will also get access to IDFA.
* If your app does not request access to IDFA the Sifo SDK will use the IDFV to track panelists.

## Release notes

6.0.6 2024-12-03
- Fix Main Thread Warning
- Fix Old iOS versions fail to sync app due to missing percent encoding

6.0.5 2024-09-16
- Fix API cookie sync
- Fix crash on clearing cookies

6.0.4 2024-08-15
- Replaced NSLog with print

6.0.3 2024-05-23
- Fixed bug related to the SifoInternet App
- Make default values to true for attributes: shouldSyncWithBackendFirst and shouldUseJsonUrlSchemeSyncFormat
- Update license to Commercial SDK (c) 2016-2024 Kantar Media Sweden AB
- No API changes

6.0.2 2024-03-13
- Fix double encoding issue
- Maintain order of query parameters
- No API changes

6.0.1 2024-02-27
- Add Privacy Manifest 

6.0.0
- Complete Swift refactor of SDK
- No API changes

5.3.0
- Swift Package Manager Support
- Removed support for CocoaPods (will probably come back)
- Added Swift wrapper Library
- Renamed objc library and removed the exposure of objc code

5.1.1
- Fix memory leak that occurred in some specific scenarios.
- Add app version info to tags and cookie.

5.1.0
- SDK skips unnecessary call to server for non-panelists.
- SDK initializer includes new parameter to specify whether IDFA and IDFV should
  be used for tracking or not.

5.0.4
- SDK not longer uses AppTrackingTransparency framework.

5.0.3
- App start tag sent for apps.

5.0.2
- SDK now asks for tracking permission on iOS 14 for panelists.
- Added support for multiple webviews.

5.0.1
- Added support for iOS 14.
- Sifo panelists now sync with IDFA and IDFV.
- SDK can now detect faulty integration and warn about it.
- Bug fixes and improvements.

## Integrate - Framework

Recommended iOS deployment target: 11.0 or later.

**1. Add library to project**

Swift Package Manager:
``` swift
.package(url: "https://github.com/kantarsifo/SifoInternet_IOS_SDK.git", from: "6.0.6")
``` 

**2. Initialize the framework**

``` SWIFT
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        TSMobileAnalytics.initialize(withCPID: ...,
                                     applicationName: ...,
                                     trackingType: ...,
                                     enableSystemIdentifierTracking: ...,
                                     isWebViewBased: ...,
                                     keychainAccessGroup: ...)
        return true
    }
}
```

* `CPID` - Your Kantar Sifo Analytics id.
* `ApplicationName` - Name of your app, can be anything you like that makes sense.
* `TrackingType` - Either `TrackPanelistsOnly` or `TrackUsersAndPanelists`.
* `IsWebViewBased` - Set this to `true` if the app’s primary interface is displayed in one or many webviews.
* `KeychainAccessGroup` - (Optional) Your app id or a shared app id if you have several apps sharing a keychain and you want to track the user between apps. If you don't need shared keychain functionality, set this to `nil`.
  When this is set, the SDK persists the generated user identifier in the shared keychain and reuses it on later launches.

## Integration - Panelist support

The purpose of this integration is to identify the user as a certain panelist. To allow the framework to integrate with the Panelist app you need to follow these additional integration steps.

**1. Add url scheme, query scheme and user tracking usage.**

Update your `info.plist` to include.
Add query scheme:
``` XML
<key>LSApplicationQueriesSchemes</key>
<array>
	<string>se.tns-sifo.internetpanelen</string>
</array>
```

Add url scheme with `<your_bundle_id>.tsmobileanalytics`:
``` XML
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>None</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>my.example.id.tsmobileanalytics</string>
    </array>
  </dict>
</array>
```

**2. Update Scene or App Delegate.**

To have this custom URL scheme picked up by the framework you have to implement the relevant method. If your app has a AppDelegate and a SceneDelegate then you should implement the SceneDelegate version. If your app only has a AppDelegate then implement the AppDelegate version.

SceneDelegate:
``` SWIFT
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
  for ctx in URLContexts {
    TSMobileAnalytics.application(UIApplication.shared, open: ctx.url, options: [:])
  }
}
```

AppDelegate:
``` SWIFT
func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
  return TSMobileAnalytics.application(app, open: url, options: options)
}
```

**3. Set webview (hybrid apps and other apps containing content in webviews).**

If your app is webview-based, or contains content in occasional webviews that should be tracked, you need to tell the framework which webviews to track by adding them:
``` SWIFT
TSMobileAnalytics.addWebView(webView)
```

And stop tracking it, if it's completely removed from the view hierarchy:
``` SWIFT
TSMobileAnalytics.removeWebView(webView)
```

**4. Shared Keychain (optional).**

If you provided a shared keychain access group.
Set `Keychain Sharing` to `ON` in the target Capabilities settings

## Sending tags

To get a good measure of the usage, your application should send a tag every time a new view or page of content is shown to the user. This tag should contain information about what content the user is seeing. For example when the user opens the application and its main view is shown, a tag should be sent. When the user shows a list, an article, a video or some other page in your application, another tag should be sent, and so on.

Streaming content is measured differently from regular content pages. “Stream started” is defined as when the actual content starts playing, after any pre-roll material that may precede it.

You need to use a unique value for “Stream started”, and use that value consistently across the app. We recommend that you synchronize this with the value you use to track “Stream started” on the web. Our recommendations is that you use one of the following values: `play`, `stream` or `webbtv`.

The framework can help you with the whole process of sending them to the server. The only thing it needs from you is for you to tell it when a view has been shown, and what content it has.

To send a tag:
``` SWIFT
TSMobileAnalytics.sendTag(withCategories: ...,
                          contentID: ...) { (success, error) in }
```

* Categories is an array of strings.
* Id is a string with the identifier of the current content.
* If you provide a completion block, it is always called. Initialization failures, validation failures, and panelist-only tracking without a synced cookie are all reported through that callback.

## Frequently asked questions (FAQ)

Q: My app does not sync with the Sifo Internet app. Why?  
A: There can be a couple of things wrong. Please make sure that:  
  - You have registered your app's bundle identifier as a custom URL scheme in your target's "Info"-tab, under "URL Types".
  - You have implemented the `openURL:` -method in your app's application delegate, and forwarded that call to the framework. For more thorough information and a step by step-guide, please  section "Integrating with SIFO Internet app to tag TNS Sifo Panelists", under "Setup".

## Implementation check

Before the app is submitted to App Store, tests need to be performed according to instructions provided by Kantar Sifo. To validate that SDK collect panelist data properly. Please contact Kantar Sifo.

## Contact information

Please send any questions or feedback to:

[*SwedishInternetSDK@kantar.com*](mailto:SwedishInternetSDK@kantar.com)
+46 (0)701 842 372

[*info@kantarsifo.com*](mailto:info@kantarsifo.com)
+46 (0)8 507 420 00
