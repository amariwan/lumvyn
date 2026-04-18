import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View

struct SMBSetupPageView: View {
    let page: OnboardingPage
    @ObservedObject var settingsStore: SettingsStore

    @State private var appeared = false
    @State private var showAutoFillNote = false
    @State private var showFolderPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // ── Header ──────────────────────────────────────────
                CompactPageIcon(page: page)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 24)

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
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: appeared)

                Spacer().frame(height: 32)

                // ── Formularkarten ──────────────────────────────────
                VStack(spacing: 16) {

                    // Karte 1: Alles in einer Karte (Host, User, Pass, Path)
                    ServerAndCredentialsCard(
                        settingsStore: settingsStore,
                        page: page,
                        showAutoFillNote: $showAutoFillNote,
                        showFolderPicker: $showFolderPicker
                    )
                    .glassCard()

                    // Karte 2: Verbindungstest (bleibt separat für Fokus)
                    ConnectionTestCard(settingsStore: settingsStore, page: page)
                        .glassCard()
                }
                .padding(.horizontal, 16)
                .offset(y: appeared ? 0 : 22)
                .opacity(appeared ? 1 : 0)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.75).delay(0.2), value: appeared)

                Spacer().frame(height: 120)
            }
        }
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
        #endif
        .sheet(isPresented: $showFolderPicker) {
            SMBFolderPickerView(isPresented: $showFolderPicker)
                .environmentObject(settingsStore)
        }
        .animateOnAppear(
            $appeared, primaryAnimation: .spring(response: 0.6, dampingFraction: 0.65).delay(0.05)
        )
        .onChange(of: settingsStore.host) { newHost in
            handleHostChange(newHost)
        }
    }

    // MARK: - Helper Methods

    private func handleHostChange(_ newHost: String) {
        // Task verhindert "Modifying state during view update" Warnungen
        Task { @MainActor in
            guard let unc = parseUNC(newHost) else { return }

            if settingsStore.host != unc.server {
                settingsStore.host = unc.server
            }
            if settingsStore.sharePath.trimmed.isEmpty, let share = unc.share {
                settingsStore.sharePath = share
                withAnimation { showAutoFillNote = true }

                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation { showAutoFillNote = false }
            }
        }
    }
}

// MARK: - Sub-Views

private struct ServerAndCredentialsCard: View {
    @ObservedObject var settingsStore: SettingsStore
    let page: OnboardingPage
    @Binding var showAutoFillNote: Bool
    @Binding var showFolderPicker: Bool

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Server & Anmeldung", icon: "server.rack", color: page.accentColor)

            // 1. HOST / IP
            OnboardingField(
                icon: "network",
                placeholder: "Host oder IP-Adresse",
                text: $settingsStore.host,
                accentColor: page.accentColor,
                keyboard: .url,
                isSecure: false,
                isError: !settingsStore.host.trimmed.isEmpty && !isValidHost(settingsStore.host)
            )

            if !settingsStore.host.trimmed.isEmpty && !isValidHost(settingsStore.host) {
                InfoMessageRow(
                    icon: "exclamationmark.triangle.fill", text: "Host ist ungültig", color: .yellow
                )
            }
            InfoMessageRow(
                icon: "info.circle", text: "Beispiel: 192.168.1.10", color: .white.opacity(0.4),
                iconColor: page.accentColor)

            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)

            // 2. USER
            OnboardingField(
                icon: "person.fill",
                placeholder: "Benutzername",
                text: $settingsStore.username,
                accentColor: page.accentColor,
                keyboard: .standard,
                isSecure: false
            )

            // 3. PASSWORD
            OnboardingField(
                icon: "lock.fill",
                placeholder: "Passwort",
                text: $settingsStore.password,
                accentColor: page.accentColor,
                keyboard: .standard,
                isSecure: true
            )

            InfoMessageRow(
                icon: "lock.shield.fill",
                text: "Das Passwort wird sicher in der Keychain gespeichert.",
                color: .white.opacity(0.4),
                iconColor: page.accentColor
            )

            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)

            // 4. PATH
            HStack(spacing: 12) {
                OnboardingField(
                    icon: "folder.fill",
                    placeholder: "Freigabe / Pfad (z.B. /photos)",
                    text: $settingsStore.sharePath,
                    accentColor: page.accentColor,
                    keyboard: .url,
                    isSecure: false
                )

                Button {
                    showFolderPicker = true
                } label: {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.title3)
                        .foregroundStyle(page.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(settingsStore.host.trimmed.isEmpty)
            }

            if showAutoFillNote {
                InfoMessageRow(
                    icon: "checkmark.circle.fill", text: "Freigabe automatisch ausgefüllt",
                    color: page.accentColor)
            }
            InfoMessageRow(
                icon: "info.circle", text: "Beispiel: /Backup/photos", color: .white.opacity(0.4),
                iconColor: page.accentColor)
        }
    }
}

private struct ConnectionTestCard: View {
    @ObservedObject var settingsStore: SettingsStore
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 10) {
            Button {
                Task { await settingsStore.testConnection() }
            } label: {
                HStack(spacing: 10) {
                    if settingsStore.isTestingConnection {
                        ProgressView().tint(.white)
                    }
                    Text("Verbindung testen")
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(page.accentColor)
            .disabled(
                settingsStore.isTestingConnection || !isValidHost(settingsStore.host)
                    || settingsStore.sharePath.trimmed.isEmpty
                    || settingsStore.hasIncompleteCredentials
            )

            ConnectionStatusMessage(settingsStore: settingsStore)
                .animation(.easeInOut, value: settingsStore.connectionStatus)
        }
    }
}

// MARK: - Reusable UI Components

private struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1.0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}

private struct InfoMessageRow: View {
    let icon: String
    let text: LocalizedStringKey
    let color: Color
    var iconColor: Color? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor ?? color)
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct ConnectionStatusMessage: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Group {
            if settingsStore.isTestingConnection {
                InfoMessageRow(
                    icon: "network", text: "Verbindung wird geprüft…", color: .white.opacity(0.7))
            } else {
                switch settingsStore.connectionStatus {
                case .ready, .authenticated:
                    InfoMessageRow(
                        icon: "checkmark.circle.fill", text: "Verbindung erfolgreich", color: .green
                    )
                case .accessDenied:
                    InfoMessageRow(
                        icon: "lock.fill", text: "Authentifizierung fehlgeschlagen", color: .red)
                case .shareNotFound:
                    InfoMessageRow(
                        icon: "folder.badge.questionmark", text: "Freigabe nicht gefunden",
                        color: .red)
                case .timedOut, .unreachable, .failed:
                    InfoMessageRow(
                        icon: "xmark.octagon.fill",
                        text: LocalizedStringKey(
                            settingsStore.connectionStatus.message ?? "Server nicht erreichbar"),
                        color: .red)
                case .portOpen:
                    InfoMessageRow(
                        icon: "exclamationmark.triangle.fill",
                        text: "Port geöffnet — Anmeldung überprüfen", color: .yellow)
                case .notConfigured:
                    InfoMessageRow(
                        icon: "gearshape.fill", text: "SMB-Konfiguration fehlt.",
                        color: .white.opacity(0.7))
                case .unknown:
                    if let error = settingsStore.connectionError, !error.isEmpty {
                        InfoMessageRow(
                            icon: "exclamationmark.triangle.fill", text: LocalizedStringKey(error),
                            color: .red)
                    } else if settingsStore.hasIncompleteCredentials {
                        InfoMessageRow(
                            icon: "person.crop.circle.badge.questionmark",
                            text: "Benutzername/Passwort fehlt (Leer für Gastzugriff)",
                            color: .white.opacity(0.7))
                    }
                case .connecting:
                    InfoMessageRow(
                        icon: "arrow.triangle.2.circlepath", text: "Verbinde…",
                        color: .white.opacity(0.7)
                    )
                }
            }
        }
    }
}

// MARK: - Modifiers

extension View {
    fileprivate func glassCard() -> some View {
        self
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}
