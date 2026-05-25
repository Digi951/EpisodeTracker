import Foundation

enum SmartListNavigation: Hashable {
    case detail(SmartListDefinition)
    case moodPicker
    case moodDetail(Mood)
}
