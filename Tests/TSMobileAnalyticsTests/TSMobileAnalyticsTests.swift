import XCTest
@testable import TSMobileAnalytics
import Security

final class TSMobileAnalyticsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        resetSDKState()
    }

    override func tearDown() {
        resetSDKState()
        super.tearDown()
    }

    func testSlashSeparatedString() {
        XCTAssertEqual([String]().slashSeparatedString(), "")
        XCTAssertEqual(["one"].slashSeparatedString(), "one")
        XCTAssertEqual(["one", "two"].slashSeparatedString(), "one/two")
        XCTAssertEqual(["one", "", "three"].slashSeparatedString(), "one/three")
    }

    func testParseURLEncodedJSONCookie() {
        let input = "%5B%7B%22key%22:%22openinsight%22,%22value%22:%22computerPan&PID=OS-PID-12345678&orvestoid=test1234&computerDbID=OS-DID-98765432&BID=OS-BID-00112233&measure=true%22,%22domain%22:%22.research-int.se%22,%22path%22:%22/%22%7D%5D"
        let array = JSONManager.parseURLEncodedJSON(input)
        let expectedDictionary = [
            "key": "openinsight",
            "value": "computerPan&PID=OS-PID-12345678&orvestoid=test1234&computerDbID=OS-DID-98765432&BID=OS-BID-00112233&measure=true",
            "domain": ".research-int.se",
            "path": "/"
        ]

        XCTAssertEqual(array?.first, expectedDictionary)
    }

    func testDecodingSyncResponse() throws {
        let testData: SyncResponse = try TestData.SyncResponse.one.load()

        XCTAssertFalse(testData.cookies.isEmpty)
        XCTAssertFalse(testData.cookies[0].domain.isEmpty)
        XCTAssertFalse(testData.cookies[0].key.isEmpty)
        XCTAssertFalse(testData.cookies[0].value.isEmpty)
    }

    func testDateNowIsDynamic() {
        let first = Date()
        Thread.sleep(forTimeInterval: 0.01)
        let second = Date()

        XCTAssertGreaterThan(second, first)
    }

    func testSyncSchedulingHelpers() {
        let now = Date(timeIntervalSince1970: 1_000)
        let shortBackoff = TSMobileAnalytics.nextSyncDate(after: nil, now: now)
        let longBackoff = TSMobileAnalytics.nextSyncDate(after: now, now: now)

        XCTAssertEqual(shortBackoff.timeIntervalSince(now), 14 * 24 * 60 * 60, accuracy: 1)
        XCTAssertEqual(longBackoff.timeIntervalSince(now), 84 * 24 * 60 * 60, accuracy: 1)
        XCTAssertTrue(TSMobileAnalytics.shouldAttemptSync(nextSyncDate: nil, now: now))
        XCTAssertFalse(TSMobileAnalytics.shouldAttemptSync(nextSyncDate: now.addingTimeInterval(60), now: now))
        XCTAssertTrue(TSMobileAnalytics.shouldAttemptSync(nextSyncDate: now.addingTimeInterval(-60), now: now))
    }

    func testSendTagCompletionFailsWhenSDKNotInitialized() {
        let expectation = expectation(description: "completion")
        var completionResult: (Bool, Error?)?

        TSMobileAnalytics.sendTag(withCategories: ["category"]) { success, error in
            completionResult = (success, error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(completionResult?.0, false)
        XCTAssertEqual(completionResult?.1 as? SendTagError, .sdkNotInitialized)
    }

    func testSendTagCompletionFailsWhenPanelistCookieIsMissing() {
        TSMobileAnalytics.initialize(
            withCPID: String(repeating: "x", count: 32),
            applicationName: "TestApp",
            trackingType: .TrackPanelistsOnly,
            enableSystemIdentifierTracking: false,
            keychainAccessGroup: nil
        )

        let expectation = expectation(description: "completion")
        var completionResult: (Bool, Error?)?

        TSMobileAnalytics.sendTag(withCategories: ["category"]) { success, error in
            completionResult = (success, error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(completionResult?.0, false)
        XCTAssertEqual(completionResult?.1 as? SendTagError, .noPanelistCookieAvailable)
    }

    func testInitializeWithoutAccessGroupReusesStoredUUID() {
        TSMobileAnalytics.initialize(
            withCPID: String(repeating: "x", count: 32),
            applicationName: "TestApp",
            trackingType: .TrackUsersAndPanelists,
            enableSystemIdentifierTracking: false,
            keychainAccessGroup: nil
        )

        let firstUUID = Storage.shared.uuidString
        TSMobileAnalytics.shared = nil

        TSMobileAnalytics.initialize(
            withCPID: String(repeating: "x", count: 32),
            applicationName: "TestApp",
            trackingType: .TrackUsersAndPanelists,
            enableSystemIdentifierTracking: false,
            keychainAccessGroup: nil
        )

        XCTAssertEqual(Storage.shared.uuidString, firstUUID)
    }

    func testKeychainWrapperPersistsAndReloadsData() {
        let keychainClient = MockKeychainClient()

        let wrapper = KeychainItemWrapper(
            identifier: "identifier",
            accessGroup: "group",
            account: "account",
            service: "service",
            keychainClient: keychainClient
        )
        wrapper.setKeychainData(Data("first".utf8))
        wrapper.reload()

        let secondWrapper = KeychainItemWrapper(
            identifier: "identifier",
            accessGroup: "group",
            account: "account",
            service: "service",
            keychainClient: keychainClient
        )

        XCTAssertEqual(wrapper.keychainData, Data("first".utf8))
        XCTAssertEqual(secondWrapper.keychainData, Data("first".utf8))

        secondWrapper.setKeychainData(Data("second".utf8))
        wrapper.reload()

        XCTAssertEqual(wrapper.keychainData, Data("second".utf8))
    }

    func testSyncURL() {
        let url = APIService().syncURL(sdkVersion: "one", appName: "two", json: "three")
        let expectedURL = URL(string: "https://sifopanelen.research-int.se/App/GetPanelistInfo?sdkversion=one&appname=two&SifoAppFrameworkInfo=three")!

        XCTAssertEqual(Set(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []),
                       Set(URLComponents(url: expectedURL, resolvingAgainstBaseURL: false)?.queryItems ?? []))
    }

    func testSendTagURL() {
        let url = APIService().sendTagURL(
            cpid: "one",
            userID: "two",
            categoryString: "three",
            contentID: "four",
            appName: "five",
            reference: "six",
            isTrackingPanelistsOnly: true,
            isWebViewBased: true,
            appVersion: "seven",
            sdkVersion: "eight"
        )

        let expectedURL = URL(string: "https://trafficgateway.research-int.se/TrafficCollector?siteId=one&appClientId=two&cp=three&appId=four&appName=five&appRef=six&TrackPanelistsOnly=true&IsWebViewBased=true&appVersion=seven&session=sdk_eight")!

        XCTAssertEqual(Set(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []),
                       Set(URLComponents(url: expectedURL, resolvingAgainstBaseURL: false)?.queryItems ?? []))
    }

    func testSendTagUsesInjectedSessionAndEncodesReservedCharacters() {
        let session = MockNetworkSession()
        session.responseData = Data("{}".utf8)
        session.response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)

        let apiService = APIService(session: session)
        let expectation = expectation(description: "completion")
        var completionResult: (Bool, Error?)?

        apiService.sendTag(
            sdkVersion: "1",
            categories: ["foo/bar", "baz qux"],
            contentID: "story?=1&x=2",
            reference: "device id",
            cpid: "cpid",
            euid: "user-id",
            isTrackingPanelistsOnly: false,
            isWebViewBased: false
        ) { success, error in
            completionResult = (success, error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)

        let queryItems = URLComponents(url: session.lastRequest?.url ?? URL(string: "https://example.com")!, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(completionResult?.0, true)
        XCTAssertNil(completionResult?.1)
        XCTAssertEqual(queryItems?.first(where: { $0.name == "cp" })?.value, "foo/bar/baz qux")
        XCTAssertEqual(queryItems?.first(where: { $0.name == "appId" })?.value, "story?=1&x=2")
    }

    private func resetSDKState() {
        TSMobileAnalytics.shared = nil
        Storage.shared.uuidString = nil
        Storage.shared.cookieString = nil
        Storage.shared.sdkVersion = nil
        Storage.shared.nextSyncDate = nil
    }
}

private final class MockNetworkSession: NetworkSession {
    var lastRequest: URLRequest?
    var responseData: Data?
    var response: URLResponse?
    var error: Error?

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> NetworkDataTask {
        lastRequest = request
        return MockNetworkDataTask {
            completionHandler(self.responseData, self.response, self.error)
        }
    }
}

private struct MockNetworkDataTask: NetworkDataTask, @unchecked Sendable {
    private let onResume: () -> Void

    init(onResume: @escaping () -> Void) {
        self.onResume = onResume
    }

    func resume() {
        onResume()
    }
}

private final class MockKeychainClient: KeychainClient {
    private var storage = [String: Data]()

    func add(_ attributes: [CFString : Any]) -> OSStatus {
        guard let key = key(for: attributes),
              let data = attributes[kSecValueData] as? Data
        else {
            return errSecParam
        }

        storage[key] = data
        return errSecSuccess
    }

    func copyMatching(_ query: [CFString : Any], result: inout CFTypeRef?) -> OSStatus {
        guard let key = key(for: query) else {
            return errSecParam
        }

        guard let data = storage[key] else {
            return errSecItemNotFound
        }

        if query[kSecReturnData] != nil {
            result = data as CFTypeRef
        }

        return errSecSuccess
    }

    func update(_ query: [CFString : Any], attributesToUpdate: [CFString : Any]) -> OSStatus {
        guard let key = key(for: query),
              storage[key] != nil,
              let data = attributesToUpdate[kSecValueData] as? Data
        else {
            return errSecItemNotFound
        }

        storage[key] = data
        return errSecSuccess
    }

    private func key(for attributes: [CFString: Any]) -> String? {
        let genericData = attributes[kSecAttrGeneric] as? Data
        let generic = genericData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let account = attributes[kSecAttrAccount] as? String ?? ""
        let service = attributes[kSecAttrService] as? String ?? ""
        let accessGroup = attributes[kSecAttrAccessGroup] as? String ?? ""

        guard !generic.isEmpty || !account.isEmpty || !service.isEmpty else {
            return nil
        }

        return [generic, account, service, accessGroup].joined(separator: "|")
    }
}
