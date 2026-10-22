import Foundation

/// The state of anything Clove fetches from the network.
enum Loadable<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }

    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    var errorMessage: String? {
        if case .failed(let message) = self { message } else { nil }
    }
}
