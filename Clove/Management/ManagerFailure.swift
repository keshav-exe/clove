import Foundation

/// An install, update, or removal that failed, ready to show in an alert.
struct ManagerFailure: Error, Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String

    init(title: String, error: any Error) {
        self.title = title
        message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}
