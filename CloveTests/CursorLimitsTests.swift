import Foundation
import SQLite3
import Testing
@testable import Clove

struct CursorLimitsTests {
    @Test func readsTheIncludedUsageAndTheCycle() throws {
        let json = """
        {"billingCycleStart": "2026-11-02T14:11:55.000Z", "billingCycleEnd": "2026-12-02T14:11:55.000Z",
         "membershipType": "pro", "limitType": "user", "isUnlimited": false,
         "individualUsage": {"plan": {"enabled": true, "used": 840, "limit": 2000, "remaining": 1160,
           "autoPercentUsed": 12, "apiPercentUsed": 61, "totalPercentUsed": 42}}}
        """
        let limits = try CursorLimitsClient.parseSummary(Data(json.utf8)).get()
        #expect(limits.agent == .cursor)
        #expect(limits.plan == "Pro")
        #expect(limits.windows.map(\.title) == ["Monthly", "API"])
        #expect(limits.windows.map(\.usedPercent) == [42, 61])
        #expect(limits.windows.first?.resetsAt == ClaudeLimitsClient.date("2026-12-02T14:11:55.000Z"))
        #expect(limits.windows.first?.length == TimeInterval(30 * 86_400))
    }

    @Test func fallsBackToUsedOverLimit() throws {
        let json = #"{"individualUsage": {"plan": {"enabled": true, "used": 500, "limit": 2000}}}"#
        let limits = try CursorLimitsClient.parseSummary(Data(json.utf8), plan: "Pro+").get()
        #expect(limits.windows.map(\.usedPercent) == [25])
        #expect(limits.plan == "Pro+")
    }

    @Test func teamSeatsWithoutAPlanReadTheMessage() throws {
        let json = """
        {"membershipType": "enterprise", "limitType": "team",
         "autoModelSelectedDisplayMessage": "You've used 87% of your included total usage",
         "individualUsage": {"overall": {"enabled": false, "used": 0, "limit": null, "remaining": null}}}
        """
        let limits = try CursorLimitsClient.parseSummary(Data(json.utf8)).get()
        #expect(limits.plan == "Enterprise")
        #expect(limits.windows.map(\.usedPercent) == [87])
    }

    @Test func unlimitedPlansHaveNothingToCount() {
        let json = #"{"isUnlimited": true, "individualUsage": {}}"#
        guard case .failure(let failure) = CursorLimitsClient.parseSummary(Data(json.utf8)) else {
            Issue.record("Expected a failure")
            return
        }
        #expect(failure.message.contains("unlimited"))
    }

    @Test func theCookieCarriesTheUserFromTheTokensSubject() throws {
        let claims = #"{"sub":"google-oauth2|user_01ABC","exp":1900000000}"#
        let payload = Data(claims.utf8).base64EncodedString()
            .replacing("+", with: "-").replacing("/", with: "_").replacing("=", with: "")
        let token = "eyJhbGciOiJIUzI1NiJ9.\(payload).signature"
        let parsed = try #require(CursorLimitsClient.jwtClaims(token))
        #expect(parsed["sub"] as? String == "google-oauth2|user_01ABC")
        let credentials = CursorLimitsClient.Credentials(accessToken: token, userID: "user_01ABC", plan: nil, expiresAt: nil)
        #expect(credentials.cookie == "WorkosCursorSessionToken=user_01ABC%3A%3A\(token)")
    }

    @Test func readsValuesFromASettingsDatabase() throws {
        let url = URL.temporaryDirectory.appending(path: "state-\(UUID().uuidString).vscdb")
        defer { try? FileManager.default.removeItem(at: url) }
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path(percentEncoded: false), &handle) == SQLITE_OK)
        sqlite3_exec(handle, "CREATE TABLE ItemTable (key TEXT UNIQUE, value BLOB); INSERT INTO ItemTable VALUES ('plain', 'pro'), ('quoted', '\"pro_plus\"');", nil, nil, nil)
        sqlite3_close(handle)
        #expect(SettingsDatabase.value(for: "plain", in: url) == "pro")
        #expect(SettingsDatabase.value(for: "quoted", in: url) == "pro_plus")
        #expect(SettingsDatabase.value(for: "missing", in: url) == nil)
    }
}
