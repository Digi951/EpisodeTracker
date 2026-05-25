import Foundation

enum AppLocalization {
    static var generalUniverseName: String {
        String(localized: "Universe.General", defaultValue: "Allgemein")
    }

    static func format(_ key: String, defaultValue: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, value: defaultValue, comment: "")
        return String(format: format, locale: .current, arguments: arguments)
    }

    static func displayName(forUniverseName name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return generalUniverseName }
        if trimmed.caseInsensitiveCompare("Allgemein") == .orderedSame {
            return generalUniverseName
        }
        return trimmed
    }
}
