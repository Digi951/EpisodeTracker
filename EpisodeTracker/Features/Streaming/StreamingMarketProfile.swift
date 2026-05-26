import Foundation

struct StreamingMarketProfile {
    let services: [StreamingService]

    static var current: StreamingMarketProfile {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "de"
        if languageCode == "de" {
            return StreamingMarketProfile(services: [.spotify, .apple, .deezer, .audible])
        }
        return StreamingMarketProfile(services: [.spotify, .apple, .audible])
    }
}
