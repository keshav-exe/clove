import SwiftUI

/// Hides the quick access panel. A struct rather than a bare closure, like
/// SwiftUI's own `DismissAction`, so the environment can compare it.
struct ClosePanelAction {
    let action: () -> Void

    func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    @Entry var closePanel = ClosePanelAction {}
}
