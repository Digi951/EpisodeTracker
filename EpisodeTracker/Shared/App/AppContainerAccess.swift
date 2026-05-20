import Combine
import Foundation
import SwiftData

@MainActor
final class AppContainerAccess: ObservableObject {
    @Published private(set) var containerSet: AppModelContainerSet

    init(containerSet: AppModelContainerSet) {
        self.containerSet = containerSet
    }
}
