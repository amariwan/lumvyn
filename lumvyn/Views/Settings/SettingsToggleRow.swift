import SwiftUI

struct SettingsToggleRow: View {
    let label: LocalizedStringKey
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(label)
            }
        }
    }
}
