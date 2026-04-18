Adding the Widget to the project

1. Create a Widget Extension target in Xcode
     - File > New > Target > Widget Extension
     - Name it e.g. `lumvynWidget`
     - Choose SwiftUI lifecycle

2. Add App Group entitlement
     - In the project target (app) and the Widget target, enable the same App Group (e.g. `group.com.example.lumyvn`) in Signing & Capabilities.
     - Update `WidgetShared.appGroup` in `lumvyn/WidgetSupport.swift` to match the App Group you configured.

3. Add the widget sources
     - Copy `lumvynWidget/LumvynWidget.swift` into the Widget target (or add the file to the new target via File inspector).
     - Add `WidgetSupport.swift` to both the app target and the widget target (File inspector -> Target Membership).

4. Data flow
     - The app writes simple keys into the shared `UserDefaults(suiteName:)` (see `WidgetSupport` keys). `UploadQueueManager` already writes `pendingCount`, `isSyncing` and `lastSyncText` and triggers `WidgetCenter.shared.reloadTimelines(ofKind:)`.

5. Test
     - Run the app on a device or simulator. Add the widget to the Home Screen (or Lock Screen accessory if supported) and verify the UI updates.

Notes

- Replace `group.com.example.lumyvn` with your real App Group identifier.
- For richer data sharing, use a shared file in the App Group container or an App Intent.
- To control update frequency more precisely, adjust the widget's timeline policy and when the app writes state.
