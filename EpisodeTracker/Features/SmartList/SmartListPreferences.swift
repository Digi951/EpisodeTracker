import Foundation

enum SmartListPreferences {
    static let storageKey = "hiddenSmartLists"

    static func hiddenLists(from rawValue: String) -> Set<SmartListDefinition> {
        Set(
            rawValue
                .split(separator: ",")
                .compactMap { SmartListDefinition(rawValue: String($0)) }
        )
    }

    static func encode(_ hiddenLists: Set<SmartListDefinition>) -> String {
        hiddenLists.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func visibleLists(from rawValue: String) -> [SmartListDefinition] {
        let hidden = hiddenLists(from: rawValue)
        return SmartListDefinition.allCases.filter { !hidden.contains($0) }
    }
}
