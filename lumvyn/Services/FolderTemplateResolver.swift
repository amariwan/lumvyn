import Foundation

/// Resolves a user-configured folder template (e.g. `{year}/{month}`) into a
/// concrete relative path for an asset upload. Supported tokens:
/// `{year}`, `{month}`, `{day}`, `{album}`, `{mediaType}`.
///
/// The resolver is intentionally pure and Foundation-only so it can be unit
/// tested without Photos or SMB dependencies.
enum FolderTemplateResolver {
    static let defaultTemplate = "{year}/{month}"

    struct Input {
        let createdAt: Date
        let albumName: String?
        let isVideo: Bool
        let calendar: Calendar

        init(createdAt: Date, albumName: String?, isVideo: Bool, calendar: Calendar = Calendar(identifier: .gregorian)) {
            self.createdAt = createdAt
            self.albumName = albumName
            self.isVideo = isVideo
            var cal = calendar
            cal.timeZone = calendar.timeZone
            self.calendar = cal
        }
    }

    /// Resolve the template into a relative directory path. Returns an empty
    /// string if the template is blank. Never returns a leading or trailing
    /// slash; segments are joined with `/`.
    static func resolve(template: String, input: Input) -> String {
        let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let components = trimmed
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { resolveComponent(String($0), input: input) }
            .map(sanitize)
            .filter { !$0.isEmpty }

        return components.joined(separator: "/")
    }

    // MARK: - Component resolution

    private static func resolveComponent(_ raw: String, input: Input) -> String {
        var result = raw
        let tokens: [(String, () -> String)] = [
            ("{year}",      { yearString(input) }),
            ("{month}",     { monthString(input) }),
            ("{day}",       { dayString(input) }),
            ("{album}",     { input.albumName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unsorted" }),
            ("{mediaType}", { input.isVideo ? "videos" : "photos" })
        ]
        for (token, provider) in tokens {
            if result.contains(token) {
                result = result.replacingOccurrences(of: token, with: provider())
            }
        }
        return result
    }

    private static func yearString(_ input: Input) -> String {
        String(format: "%04d", input.calendar.component(.year, from: input.createdAt))
    }

    private static func monthString(_ input: Input) -> String {
        String(format: "%02d", input.calendar.component(.month, from: input.createdAt))
    }

    private static func dayString(_ input: Input) -> String {
        String(format: "%02d", input.calendar.component(.day, from: input.createdAt))
    }

    // MARK: - Sanitization

    /// Strip characters that SMB/NTFS refuse in directory names. Collapses any
    /// stripped runs to a single underscore and removes trailing dots/spaces
    /// (which Windows rejects).
    private static func sanitize(_ segment: String) -> String {
        let forbidden: Set<Character> = ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", "\0"]
        var out = ""
        var lastWasUnderscore = false
        for ch in segment {
            if forbidden.contains(ch) || ch.asciiValue.map({ $0 < 0x20 }) == true {
                if !lastWasUnderscore {
                    out.append("_")
                    lastWasUnderscore = true
                }
            } else {
                out.append(ch)
                lastWasUnderscore = false
            }
        }
        while let last = out.last, last == "." || last == " " {
            out.removeLast()
        }
        return out
    }

    // MARK: - Preview

    /// Build a preview path used by the settings UI. Uses the current date,
    /// a placeholder album, and photo media type so the user can see how the
    /// template will be expanded at upload time.
    static func previewPath(template: String, now: Date = Date()) -> String {
        let resolved = resolve(
            template: template,
            input: Input(
                createdAt: now,
                albumName: NSLocalizedString("Sommer 2024", comment: "Folder template preview: example album name"),
                isVideo: false
            )
        )
        return resolved
    }
}
