import Foundation

/// EINGEFRORENER VERTRAG. Nie nachträglich ändern — Slugs sind Sync-Identitäten.
/// Bei nötigen Änderungen nur additiv versionieren.
enum SpecialEpisodeSlug {
    static func make(title: String, releaseYear: Int, universeKey: String = "") -> String {
        let core = slugifyCore(title)
        if core.isEmpty {
            let seed = "\(universeKey)|\(title)|\(releaseYear)"
            return "h-\(stableHash(seed))"
        }
        return "\(core)-\(releaseYear)"
    }

    private static func slugifyCore(_ input: String) -> String {
        let lowered = input.lowercased()
        var mapped = ""
        for scalar in lowered.unicodeScalars {
            switch scalar {
            case "ä": mapped += "ae"
            case "ö": mapped += "oe"
            case "ü": mapped += "ue"
            case "ß": mapped += "ss"
            default: mapped.unicodeScalars.append(scalar)
            }
        }
        let allowed = mapped.map { ch -> Character in
            (ch.isLetter || ch.isNumber) ? ch : " "
        }
        let collapsed = String(allowed)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed
    }

    /// Stabiler, plattform-/version-unabhängiger Hash (FNV-1a).
    private static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
