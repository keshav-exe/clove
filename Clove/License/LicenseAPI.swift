import Foundation

enum LicenseAPI {
    enum Error: Swift.Error, LocalizedError {
        case invalidResponse
        case rejected(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Could not read the license server response."
            case .rejected(let message):
                message
            }
        }
    }

    private struct Response: Decodable {
        let activated: Bool?
        let valid: Bool?
        let deactivated: Bool?
        let error: String?
        let instance: Instance?
        let meta: Meta?

        struct Instance: Decodable {
            let id: String
        }

        struct Meta: Decodable {
            let customerEmail: String?

            enum CodingKeys: String, CodingKey {
                case customerEmail = "customer_email"
            }
        }
    }

    static func activate(licenseKey: String) async throws -> LicenseRecord {
        let response = try await post(
            path: "licenses/activate",
            fields: [
                "license_key": licenseKey,
                "instance_name": MachineIdentity.instanceName,
            ]
        )

        guard response.activated == true, let instanceID = response.instance?.id else {
            throw Error.rejected(response.error ?? "This license key could not be activated.")
        }

        let now = Date.now
        return LicenseRecord(
            licenseKey: licenseKey,
            instanceID: instanceID,
            instanceName: MachineIdentity.instanceName,
            customerEmail: response.meta?.customerEmail,
            activatedAt: now,
            lastValidatedAt: now
        )
    }

    static func validate(record: LicenseRecord) async throws -> LicenseRecord {
        let response = try await post(
            path: "licenses/validate",
            fields: [
                "license_key": record.licenseKey,
                "instance_id": record.instanceID,
            ]
        )

        guard response.valid == true else {
            throw Error.rejected(response.error ?? "This license is no longer valid on this Mac.")
        }

        var updated = record
        updated.lastValidatedAt = .now
        if let email = response.meta?.customerEmail {
            updated = LicenseRecord(
                licenseKey: updated.licenseKey,
                instanceID: updated.instanceID,
                instanceName: updated.instanceName,
                customerEmail: email,
                activatedAt: updated.activatedAt,
                lastValidatedAt: updated.lastValidatedAt
            )
        }
        return updated
    }

    static func deactivate(record: LicenseRecord) async throws {
        let response = try await post(
            path: "licenses/deactivate",
            fields: [
                "license_key": record.licenseKey,
                "instance_id": record.instanceID,
            ]
        )

        guard response.deactivated == true else {
            throw Error.rejected(response.error ?? "Could not deactivate this Mac.")
        }
    }

    private static func post(path: String, fields: [String: String]) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://api.lemonsqueezy.com/v1/\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(fields)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }

        let envelope = try JSONDecoder().decode(Response.self, from: data)
        if let message = envelope.error, !message.isEmpty {
            throw Error.rejected(message)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw Error.rejected("License server returned HTTP \(http.statusCode).")
        }
        return envelope
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        fields
            .map { key, value in
                "\(formEncode(key))=\(formEncode(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}
