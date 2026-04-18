import SwiftUI

struct DSPillPicker<Value: Hashable, Label: View>: View {
    @Binding var selection: Value
    let options: [Value]
    @ViewBuilder var label: (Value) -> Label

    var tint: Color = DS.Palette.accent
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection

                Button {
                    withAnimation(DSMotion.bouncy) { selection = option }
                    #if os(iOS)
                    UISelectionFeedbackGenerator().selectionChanged()
                    #endif
                } label: {
                    label(option)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(tint.gradient)
                                    .matchedGeometryEffect(id: "pillBG", in: ns)
                                    .shadow(color: tint.opacity(0.45), radius: 12, x: 0, y: 6)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: DS.Stroke.thin)
        }
        .dsShadow(DS.Shadow.soft)
    }
}
