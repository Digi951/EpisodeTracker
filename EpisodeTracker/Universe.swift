import Foundation
import SwiftData

@Model
final class Universe {
    var name: String
    var episodes: [Episode]

    init(name: String, episodes: [Episode] = []) {
        self.name = name
        self.episodes = episodes
    }
}
