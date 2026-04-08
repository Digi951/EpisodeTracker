import SwiftUI

#if canImport(UIKit)
import UIKit

extension View {
    func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
#else
extension View {
    func dismissKeyboard() {}
}
#endif
