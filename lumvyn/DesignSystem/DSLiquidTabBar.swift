import SwiftUI

struct DSTabItem<Tag: Hashable>: Identifiable {
    let id = UUID()
    let tag: Tag
    let titleKey: LocalizedStringKey
    let systemImage: String
}

struct DSLiquidTabBar<Tag: Hashable>: View {
    @Binding var selection: Tag
    let items: [DSTabItem<Tag>]
    var tint: Color = DS.Palette.accent

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let isSelected = item.tag == selection

                Button {
                    withAnimation(DSMotion.fluid) { selection = item.tag }
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    #endif
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(tint.gradient)
                                    .frame(width: 56, height: 32)
                                    .matchedGeometryEffect(id: "tabBG", in: ns)
                                    .shadow(color: tint.opacity(0.45), radius: 10, x: 0, y: 5)
                            }

                            Image(systemName: item.systemImage)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : .secondary)
                                .symbolEffect(.bounce, value: isSelected)
                        }
                        .frame(height: 32)

                        Text(item.titleKey)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? tint : .secondary)
                            .opacity(isSelected ? 1.0 : 0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), lineWidth: DS.Stroke.thin)
        }
        .dsShadow(DS.Shadow.lift)
        .padding(.horizontal, DS.Spacing.md)
    }
}
