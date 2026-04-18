import SwiftUI

enum DS {
    enum Radius {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let thin: CGFloat = 0.8
        static let regular: CGFloat = 1.2
    }

    enum Palette {
        static let accent       = Color(red: 0.12, green: 0.58, blue: 0.98)
        static let accentSoft   = Color(red: 0.32, green: 0.72, blue: 1.00)
        static let accentDeep   = Color(red: 0.06, green: 0.36, blue: 0.82)

        static let auroraTeal   = Color(red: 0.18, green: 0.78, blue: 0.78)
        static let auroraIndigo = Color(red: 0.36, green: 0.34, blue: 0.92)
        static let auroraPink   = Color(red: 0.96, green: 0.40, blue: 0.66)
        static let auroraAmber  = Color(red: 0.99, green: 0.66, blue: 0.18)
        static let auroraMint   = Color(red: 0.36, green: 0.92, blue: 0.66)

        static let danger       = Color(red: 0.98, green: 0.32, blue: 0.36)
        static let warning      = Color(red: 0.99, green: 0.66, blue: 0.18)
        static let success      = Color(red: 0.30, green: 0.84, blue: 0.50)
    }

    enum Shadow {
        static let soft = ShadowStyle(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
        static let lift = ShadowStyle(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
        static let glow = ShadowStyle(color: Palette.accent.opacity(0.45), radius: 22, x: 0, y: 10)
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

extension View {
    func dsShadow(_ style: DS.ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
