import XCTest
@testable import lumvyn

#if os(iOS)
import UIKit
#endif

final class SettingsStorePersistenceTests: XCTestCase {

    func testPasswordPersistedOnWillResignActive() async {
        // ensure clean state
        try? KeychainStorage.deleteValue(forKey: "SMBPassword")

        let store = await MainActor.run { SettingsStore() }

        await MainActor.run {
            store.username = "user"
            store.password = "persist-me"
        }

        #if os(iOS)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        #else
        NotificationCenter.default.post(name: Notification.Name("TestWillResignActive"), object: nil)
        #endif

        // allow brief time for synchronous write
        try? await Task.sleep(nanoseconds: 200_000_000)

        let saved = KeychainStorage.string(forKey: "SMBPassword")
        XCTAssertEqual(saved, "persist-me")
    }
}
