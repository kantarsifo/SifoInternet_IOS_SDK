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

Minimum iOS deployment target: 9.0

**1. Add library to project**

Swift Package Manager:
``` Ruby
source 'https://github.com/kantarsifo/SifoInternet_IOS_SDK.git'
``` 

**2. Initialize the framework**

``` SWIFT
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        TSAnalyticsSwift.initialize(withCPID: ...,
                                     applicationName: ...,
                                     trackingType: ...,
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
* `KeychainAccessGroup` - (Optional) Your app id or a shared app id if you have several apps sharing a keychain and your want to track the user between apps. If you don't need to use Shared Keychain functionality, then set this to `nil`.

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
TSMobileAnalytics.addWebview(webView)
```

And stop tracking it, if it's completely removed from the view hierarchy:
``` SWIFT
TSMobileAnalytics.removeWebview(webView)
```

**4. Shared Keychain (optional).**

If you provided a shared keychain access group.
Set `Keychain Sharing` to `ON` in the target Capabilities settings

## React Native

This section covers integrating the Sifo SDK into a React Native project. Two setups are described: **bare React Native** (CLI) and **Expo**. All steps are iOS-only.

---

### Bare React Native

**1. Add the package**

Open `ios/MyApp.xcworkspace` in Xcode, go to **File → Add Package Dependencies…**, and enter:

```
https://github.com/kantarsifo/SifoInternet_IOS_SDK.git
```

Select the `TSMobileAnalytics` library and add it to your app target.

**2. Configure Info.plist**

Add the query scheme and URL scheme entries (replace `my.bundle.id` with your actual bundle identifier):

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>se.tns-sifo.internetpanelen</string>
</array>

<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>None</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER).tsmobileanalytics</string>
    </array>
  </dict>
</array>
```

**3. Create the native module**

Create two files to expose the SDK to React Native's JavaScript layer.

`ios/MyApp/SifoModule.swift`:

```swift
import Foundation
import TSMobileAnalytics

@objc(SifoModule)
class SifoModule: NSObject {

  @objc(sendTag:contentID:)
  func sendTag(categories: [String], contentID: String) {
    TSMobileAnalytics.sendTag(
      withCategories: categories,
      contentID: contentID
    ) { _, error in
      if let error = error { print("[Sifo] \(error)") }
    }
  }

  @objc static func requiresMainQueueSetup() -> Bool { false }
}
```

`ios/MyApp/SifoModule.m` (required to expose the Swift module to React Native):

```objc
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(SifoModule, NSObject)
RCT_EXTERN_METHOD(sendTag:(NSArray *)categories contentID:(NSString *)contentID)
@end
```

When Xcode prompts you to create a bridging header after adding the Swift file, click **Yes**. Then add the following to it:

```objc
#import <React/RCTBridgeModule.h>
```

> **Note:** If Xcode does not prompt (e.g. your project already has Swift files), create the bridging header manually. Add an empty `.h` file to `ios/MyApp/`, then set its path in **Build Settings → Swift Compiler — General → Objective-C Bridging Header**, and add the import above.

**4. Initialize in AppDelegate**

React Native 0.77 and later — projects use a `RCTReactNativeFactory`-based `AppDelegate`. Update `ios/MyApp/AppDelegate.swift`:

```swift
import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import TSMobileAnalytics

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    TSMobileAnalytics.initialize(
      withCPID: "YOUR_CPID",
      applicationName: "YourAppName",
      trackingType: .TrackPanelistsOnly,
      enableSystemIdentifierTracking: false,
      isWebViewBased: false,
      keychainAccessGroup: nil
    )

    let delegate = ReactNativeDelegate()
    let factory = RCTReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()
    reactNativeDelegate = delegate
    reactNativeFactory = factory

    window = UIWindow(frame: UIScreen.main.bounds)
    factory.startReactNative(
      withModuleName: "MyApp",
      in: window,
      launchOptions: launchOptions
    )
    return true
  }

  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    TSMobileAnalytics.application(app, open: url, options: options)
    return true
  }
}

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
    #if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
    #else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
    #endif
  }
}
```

React Native 0.76 and earlier — projects use an Objective-C++ `AppDelegate`. Update `ios/MyApp/AppDelegate.mm`:

```objc
#import "AppDelegate.h"
#import "MyApp-Swift.h"

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.moduleName = @"MyApp";
  self.initialProps = @{};
  [TSMobileAnalytics initializeWithCPID:@"YOUR_CPID"
                        applicationName:@"YourAppName"
                           trackingType:TrackingTypeTrackPanelistsOnly
          enableSystemIdentifierTracking:NO
                        isWebViewBased:NO
                    keychainAccessGroup:nil];
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
  [TSMobileAnalytics application:app open:url options:options];
  return YES;
}
```

**5. Send tags from JavaScript**

```js
// utils/analytics.js
import { NativeModules, Platform } from 'react-native';

const { SifoModule } = NativeModules;

export function trackView(categories, contentID) {
  if (Platform.OS === 'ios' && SifoModule) {
    SifoModule.sendTag(categories, contentID);
  }
}
```

Call it whenever a new screen or piece of content is shown:

```js
import { useEffect } from 'react';
import { trackView } from '../utils/analytics';

export default function ArticleScreen({ article }) {
  useEffect(() => {
    trackView(['news', article.section], article.id);
  }, [article.id]);
}
```

---

### Expo

**1. Run prebuild**

```bash
npx expo prebuild
```

This generates the `ios/` folder. All steps below take place inside it.

**2. Add the SPM package**

Open `ios/MyApp.xcworkspace` in Xcode, go to **File → Add Package Dependencies…**, and enter:

```
https://github.com/kantarsifo/SifoInternet_IOS_SDK.git
```

Select the `TSMobileAnalytics` library and add it to your app target.

**3. Configure Info.plist**

The config plugin below handles this automatically. If you prefer to do it manually, add the same entries as in the bare React Native section to `ios/MyApp/Info.plist`.

To apply it automatically, create `plugins/withSifoSDK.js` in your project root:

```js
const { withInfoPlist } = require('@expo/config-plugins');

const withSifoPlist = (config) =>
  withInfoPlist(config, (mod) => {
    const plist = mod.modResults;
    const bundleId = config.ios?.bundleIdentifier ?? 'com.example.app';

    if (!plist.LSApplicationQueriesSchemes) plist.LSApplicationQueriesSchemes = [];
    if (!plist.LSApplicationQueriesSchemes.includes('se.tns-sifo.internetpanelen')) {
      plist.LSApplicationQueriesSchemes.push('se.tns-sifo.internetpanelen');
    }

    if (!plist.CFBundleURLTypes) plist.CFBundleURLTypes = [];
    const scheme = `${bundleId}.tsmobileanalytics`;
    if (!plist.CFBundleURLTypes.some((t) => t.CFBundleURLSchemes?.includes(scheme))) {
      plist.CFBundleURLTypes.push({ CFBundleTypeRole: 'None', CFBundleURLSchemes: [scheme] });
    }

    return mod;
  });

module.exports = (config) => withSifoPlist(config);
```

Register it in `app.json`:

```json
{
  "expo": {
    "plugins": ["./plugins/withSifoSDK"],
    "ios": {
      "bundleIdentifier": "com.yourcompany.myapp"
    }
  }
}
```

**4. Create the native module files**

Create both files inside the app target folder — **not** the `ios/` root:

`ios/MyApp/SifoModule.swift`:

```swift
import Foundation
import TSMobileAnalytics

@objc(SifoModule)
class SifoModule: NSObject {

  @objc(sendTag:contentID:)
  func sendTag(categories: [String], contentID: String) {
    TSMobileAnalytics.sendTag(
      withCategories: categories,
      contentID: contentID
    ) { _, error in
      if let error = error { print("[Sifo] \(error)") }
    }
  }

  @objc static func requiresMainQueueSetup() -> Bool { false }
}
```

`ios/MyApp/SifoModule.m`:

```objc
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(SifoModule, NSObject)
RCT_EXTERN_METHOD(sendTag:(NSArray *)categories contentID:(NSString *)contentID)
@end
```

**5. Add both files to the Xcode target**

Files on disk are not automatically included in the build. In Xcode, right-click the `MyApp` group in the left sidebar, choose **Add Files to "MyApp"…**, and select both `SifoModule.swift` and `SifoModule.m`. Make sure **Add to targets: MyApp** is checked.

When prompted about the bridging header, click **Yes**. Then add the following to the generated header:

```objc
#import <React/RCTBridgeModule.h>
```

If Xcode does not prompt (the project already has Swift files), create the bridging header manually and set its path in **Build Settings → Swift Compiler — General → Objective-C Bridging Header**.

**6. Initialize in AppDelegate**

Expo generates an `ExpoAppDelegate`-based `AppDelegate.swift`. Add the `TSMobileAnalytics.initialize` call and the `openURL` handler to `ios/MyApp/AppDelegate.swift`:

```swift
import Expo
import React
import ReactAppDependencyProvider
import TSMobileAnalytics

@UIApplicationMain
public class AppDelegate: ExpoAppDelegate {
  var window: UIWindow?
  var reactNativeDelegate: ExpoReactNativeFactoryDelegate?
  var reactNativeFactory: RCTReactNativeFactory?

  public override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    TSMobileAnalytics.initialize(
      withCPID: "YOUR_CPID",
      applicationName: "YourAppName",
      trackingType: .TrackPanelistsOnly,
      enableSystemIdentifierTracking: false,
      isWebViewBased: false,
      keychainAccessGroup: nil
    )

    let delegate = ReactNativeDelegate()
    let factory = ExpoReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()
    reactNativeDelegate = delegate
    reactNativeFactory = factory
    bindReactNativeFactory(factory)

    #if os(iOS) || os(tvOS)
    window = UIWindow(frame: UIScreen.main.bounds)
    factory.startReactNative(
      withModuleName: "main",
      in: window,
      launchOptions: launchOptions)
    #endif

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  public override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    TSMobileAnalytics.application(app, open: url, options: options)
    return super.application(app, open: url, options: options)
      || RCTLinkingManager.application(app, open: url, options: options)
  }

  public override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    let result = RCTLinkingManager.application(application, continue: userActivity, restorationHandler: restorationHandler)
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler) || result
  }
}

class ReactNativeDelegate: ExpoReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    bridge.bundleURL ?? bundleURL()
  }

  override func bundleURL() -> URL? {
    #if DEBUG
    return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: ".expo/.virtual-metro-entry")
    #else
    return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
    #endif
  }
}
```

**7. Send tags from JavaScript**

Same as the bare React Native section — see **Send tags from JavaScript** above.

**8. Build**

```bash
eas build --platform ios
# or for local builds:
npx expo run:ios
```

> **Bare workflow:** The `ios/` folder already exists. Follow steps 2–7 above directly, and use the config plugin to ensure `npx expo prebuild` re-applies your `Info.plist` changes idempotently rather than overwriting them.

---

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
