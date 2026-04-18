import Foundation

/// Shared constants for app/widget communication. Replace `appGroup` with your real App Group ID
/// after you add the Widget extension and enable the App Group for both targets.
struct WidgetShared {
    // IMPORTANT: this value must match the App Group enabled in Xcode Entitlements
    // for BOTH the main app (tasio.lumvyn) and the widget extension
    // (tasio.lumvyn.lumvynWidget-Extension). Without that, the widget reads empty defaults.
    static let appGroup = "group.tasio.lumvyn"

    static let keyPending = "widget.pendingCount"
    static let keyIsSyncing = "widget.isSyncing"
    static let keyLastSyncText = "widget.lastSyncText"

    static let kind = "LumvynWidget"
}
