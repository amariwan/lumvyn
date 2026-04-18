import SwiftUI

struct AuthSetupPageView: View {
    let page: OnboardingPage
    @ObservedObject var settingsStore: SettingsStore

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                CompactPageIcon(page: page)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 28)

                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(page.subtitle)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 28)
                .offset(y: appeared ? 0 : 18)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: appeared)

                Spacer().frame(height: 36)

                VStack(spacing: 14) {
                    OnboardingField(
                        icon: "person.fill",
                        placeholder: NSLocalizedString("Benutzername", comment: ""),
                        text: $settingsStore.username,
                        accentColor: page.accentColor,
                        keyboard: .standard,
                        isSecure: false
                    )

                    OnboardingField(
                        icon: "lock.fill",
                        placeholder: NSLocalizedString("Passwort", comment: ""),
                        text: $settingsStore.password,
                        accentColor: page.accentColor,
                        keyboard: .standard,
                        isSecure: true
                    )

                    if settingsStore.password.trimmed.isEmpty,
                       let saved = settingsStore.savedPassword {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill")
                                    .font(.caption)
                                    .foregroundStyle(page.accentColor.opacity(0.9))
                                Text(LocalizedStringKey("Passwort aus Keychain verwendet."))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.65))
                            }

                            HStack(spacing: 12) {
                                Button(action: { settingsStore.password = saved }) {
                                    Text(LocalizedStringKey("Gespeichertes Passwort verwenden"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(page.accentColor))
                                }

                                Button(action: { settingsStore.password = "" }) {
                                    Text(LocalizedStringKey("Anderes Passwort verwenden"))
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12)))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption)
                            .foregroundStyle(page.accentColor.opacity(0.8))
                        Text(LocalizedStringKey("Das Passwort wird sicher in der Keychain gespeichert."))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 28)
                .offset(y: appeared ? 0 : 22)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.2), value: appeared)

                Spacer().frame(height: 160)
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .animateOnAppear($appeared, primaryAnimation: .spring(response: 0.6, dampingFraction: 0.65).delay(0.05))
    }
}
