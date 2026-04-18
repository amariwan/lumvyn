import SwiftUI

struct OnboardingPage: Identifiable {
    let id: Int
    let kind: OnboardingPageKind
    let systemImage: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let gradientColors: [Color]
}

enum OnboardingPageKind {
    case info
    case smbSetup
    case checklist
}

let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        kind: .info,
        systemImage: "arrow.up.to.line.circle.fill",
        title: NSLocalizedString("Willkommen bei Lumvyn", comment: ""),
        subtitle: NSLocalizedString("Deine Fotos & Videos automatisch auf deinen Heimserver – sicher, privat, ohne Cloud.", comment: ""),
        accentColor: .blue,
        gradientColors: [Color(red: 0.04, green: 0.05, blue: 0.22), Color(red: 0.07, green: 0.08, blue: 0.38)]
    ),
    OnboardingPage(
        id: 1,
        kind: .smbSetup,
        systemImage: "server.rack",
        title: NSLocalizedString("SMB-Server einrichten", comment: ""),
        subtitle: NSLocalizedString("Server, Freigabepfad und Anmeldedaten eingeben.", comment: ""),
        accentColor: .cyan,
        gradientColors: [Color(red: 0.02, green: 0.10, blue: 0.22), Color(red: 0.0, green: 0.18, blue: 0.30)]
    ),
    OnboardingPage(
        id: 2,
        kind: .info,
        systemImage: "bolt.fill",
        title: NSLocalizedString("Automatisch im Hintergrund", comment: ""),
        subtitle: NSLocalizedString("Sobald du mit WLAN verbunden bist, lädt Lumvyn neue Medien selbstständig hoch.", comment: ""),
        accentColor: .purple,
        gradientColors: [Color(red: 0.10, green: 0.04, blue: 0.26), Color(red: 0.18, green: 0.06, blue: 0.38)]
    ),
    OnboardingPage(
        id: 3,
        kind: .checklist,
        systemImage: "checklist",
        title: NSLocalizedString("ChecklistPageTitle", comment: ""),
        subtitle: NSLocalizedString("ChecklistPageSubtitle", comment: ""),
        accentColor: .teal,
        gradientColors: [Color(red: 0.02, green: 0.12, blue: 0.16), Color(red: 0.02, green: 0.22, blue: 0.24)]
    ),
    OnboardingPage(
        id: 4,
        kind: .info,
        systemImage: "checkmark.circle.fill",
        title: NSLocalizedString("Alles bereit!", comment: ""),
        subtitle: NSLocalizedString("Dein Server ist konfiguriert. Lumvyn startet jetzt automatisch mit dem Upload.", comment: ""),
        accentColor: .green,
        gradientColors: [Color(red: 0.02, green: 0.12, blue: 0.10), Color(red: 0.03, green: 0.22, blue: 0.18)]
    )
]
