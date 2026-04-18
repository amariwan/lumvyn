import SwiftUI

struct SettingsIconRow<Content: View>: View {
    let icon: String
    let color: Color
    let content: Content

    init(icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            content
        }
    }
}
