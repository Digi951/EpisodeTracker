import Foundation

struct StreamingMarketProfile {
    let services: [StreamingService]

    var defaultService: StreamingService {
        services.first ?? .apple
    }

    /// Auswahl erfolgt bewusst über den Sprachcode, nicht über die Region — damit
    /// bleibt sie konsistent zum Katalog-Sprachfilter in `ManagedCatalogSource`.
    private static let profiles: [String: [StreamingService]] = [
        "de": [.spotify, .apple, .deezer, .audible],
        "en": [.apple, .audible, .spotify],
        "fr": [.spotify, .deezer, .apple, .audible],
        "nl": [.spotify, .storytel, .apple],
        "pl": [.audioteka, .spotify, .storytel, .apple]
    ]

    private static let fallbackServices: [StreamingService] = [.apple, .audible]

    static func profile(forLanguageCode code: String) -> StreamingMarketProfile {
        StreamingMarketProfile(services: profiles[code.lowercased()] ?? fallbackServices)
    }

    static var current: StreamingMarketProfile {
        profile(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "de")
    }
}
