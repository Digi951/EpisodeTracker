import Foundation

enum SmartListPreferences {
    static let hiddenStorageKey = "hiddenSmartLists"
    static let orderStorageKey = "smartListOrder"

    static func hiddenLists(from rawValue: String) -> Set<SmartListDefinition> {
        Set(
            rawValue
                .split(separator: ",")
                .compactMap { SmartListDefinition(rawValue: String($0)) }
        )
    }

    static func encodeHidden(_ hiddenLists: Set<SmartListDefinition>) -> String {
        hiddenLists.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func orderedLists(from rawValue: String) -> [SmartListDefinition] {
        let saved = rawValue
            .split(separator: ",")
            .compactMap { SmartListDefinition(rawValue: String($0)) }

        var result: [SmartListDefinition] = []
        for item in saved where !result.contains(item) {
            result.append(item)
        }
        for item in SmartListDefinition.allCases where !result.contains(item) {
            result.append(item)
        }
        return result
    }

    static func encodeOrder(_ order: [SmartListDefinition]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }

    static func visibleLists(orderRaw: String, hiddenRaw: String) -> [SmartListDefinition] {
        let hidden = hiddenLists(from: hiddenRaw)
        return orderedLists(from: orderRaw).filter { !hidden.contains($0) }
    }
}
