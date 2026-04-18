import SwiftUI

enum FieldKeyboard {
    case url
    case standard
}

struct OnboardingField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let accentColor: Color
    let keyboard: FieldKeyboard
    let isSecure: Bool
    let isError: Bool

    init(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        accentColor: Color,
        keyboard: FieldKeyboard,
        isSecure: Bool,
        isError: Bool = false
    ) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.accentColor = accentColor
        self.keyboard = keyboard
        self.isSecure = isSecure
        self.isError = isError
    }

    @FocusState private var focused: Bool
    private var hasContent: Bool { !text.isEmpty }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(focused ? accentColor : Color.white.opacity(0.45))
                .frame(width: 22)
                .animation(.easeInOut(duration: 0.2), value: focused)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($focused)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .tint(accentColor)
            } else {
                TextField(placeholder, text: $text)
                    .focused($focused)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .tint(accentColor)
                    #if os(iOS)
                    .keyboardType(keyboard == .url ? .URL : .default)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled(true)
            }

            if isError {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(focused ? 0.10 : hasContent ? 0.08 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isError ? Color.red.opacity(0.95) :
                            focused  ? accentColor.opacity(0.80) :
                            hasContent ? accentColor.opacity(0.28) :
                            Color.white.opacity(0.12),
                            lineWidth: isError ? 2.0 : 1.5
                        )
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focused)
    }
}
