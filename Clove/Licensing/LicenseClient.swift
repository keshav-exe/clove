import Foundation

/// Dodo Payments' public license endpoints. They need no API key.
enum LicenseClient {
    enum Failure: Error, Equatable {
        case invalidKey
        case activationLimitReached
        case wrongProduct
        case offline
        case server(Int)

        var message: String {
            switch self {
            case .invalidKey: "That key wasn't recognised. Check it against your purchase email."
            case .activationLimitReached: "This key is already active on another Mac. Deactivate it there in Settings, then try again."
            case .wrongProduct: "That key is for a different product."
            case .offline: "Clove couldn't reach Dodo Payments. Check your connection and try again."
            case .server(let status): "Dodo Payments returned an error (\(status)). Try again in a moment."
            }
        }
    }

    private struct Activation: Decodable {
        struct Product: Decodable {
            let productID: String

            enum CodingKeys: String, CodingKey {
                case productID = "product_id"
            }
        }

        let id: String
        let product: Product
    }

    private struct Validation: Decodable {
        let valid: Bool
    }

    /// Activates `key` on this Mac and returns the instance to keep for later checks.
    static func activate(key: String, deviceName: String) async throws(Failure) -> String {
        let data = try await post("licenses/activate", ["license_key": key, "name": deviceName])
        guard let activation = try? JSONDecoder().decode(Activation.self, from: data) else {
            throw .server(200)
        }
        guard LicenseConfiguration.productIDs.contains(activation.product.productID) else {
            // Don't hold a slot on someone else's product.
            try? await deactivate(key: key, instanceID: activation.id)
            throw .wrongProduct
        }
        return activation.id
    }

    /// Whether the key is still active and still activated on this Mac.
    static func validate(key: String, instanceID: String) async throws(Failure) -> Bool {
        let data = try await post("licenses/validate", ["license_key": key, "license_key_instance_id": instanceID])
        return (try? JSONDecoder().decode(Validation.self, from: data))?.valid ?? false
    }

    static func deactivate(key: String, instanceID: String) async throws(Failure) {
        _ = try await post("licenses/deactivate", ["license_key": key, "license_key_instance_id": instanceID])
    }

    private static func post(_ path: String, _ body: [String: String]) async throws(Failure) -> Data {
        var request = URLRequest(url: LicenseConfiguration.apiBase.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: return data
        case 422: throw .activationLimitReached
        case 400, 403, 404: throw .invalidKey
        default: throw .server(status)
        }
    }
}
