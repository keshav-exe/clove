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

    private static var baseURL: URL {
        #if DEBUG
        URL(string: "https://test.dodopayments.com")!
        #else
        URL(string: "https://live.dodopayments.com")!
        #endif
    }

    private struct ActivateRequest: Encodable {
        let licenseKey: String
        let name: String

        enum CodingKeys: String, CodingKey {
            case licenseKey = "license_key"
            case name
        }
    }

    private struct ActivateResponse: Decodable {
        let id: String
        let customer: Customer?

        struct Customer: Decodable {
            let email: String?
        }
    }

    private struct ValidateRequest: Encodable {
        let licenseKey: String
        let licenseKeyInstanceID: String

        enum CodingKeys: String, CodingKey {
            case licenseKey = "license_key"
            case licenseKeyInstanceID = "license_key_instance_id"
        }
    }

    private struct ValidateResponse: Decodable {
        let valid: Bool
    }

    private struct DeactivateRequest: Encodable {
        let licenseKey: String
        let licenseKeyInstanceID: String

        enum CodingKeys: String, CodingKey {
            case licenseKey = "license_key"
            case licenseKeyInstanceID = "license_key_instance_id"
        }
    }

    private struct APIErrorBody: Decodable {
        let code: String?
        let message: String?
    }

    static func activate(licenseKey: String) async throws -> LicenseRecord {
        let response: ActivateResponse = try await post(
            path: "licenses/activate",
            body: ActivateRequest(licenseKey: licenseKey, name: MachineIdentity.instanceName),
            expectedStatus: 201
        )

        let now = Date.now
        return LicenseRecord(
            licenseKey: licenseKey,
            instanceID: response.id,
            instanceName: MachineIdentity.instanceName,
            customerEmail: response.customer?.email,
            activatedAt: now,
            lastValidatedAt: now
        )
    }

    static func validate(record: LicenseRecord) async throws -> LicenseRecord {
        let response: ValidateResponse = try await post(
            path: "licenses/validate",
            body: ValidateRequest(
                licenseKey: record.licenseKey,
                licenseKeyInstanceID: record.instanceID
            ),
            expectedStatus: 200
        )

        guard response.valid else {
            throw Error.rejected("This license is no longer valid on this Mac.")
        }

        var updated = record
        updated.lastValidatedAt = .now
        return updated
    }

    static func deactivate(record: LicenseRecord) async throws {
        try await post(
            path: "licenses/deactivate",
            body: DeactivateRequest(
                licenseKey: record.licenseKey,
                licenseKeyInstanceID: record.instanceID
            ),
            expectedStatus: 200
        )
    }

    private static func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        expectedStatus: Int
    ) async throws -> Response {
        let data = try await send(path: path, body: body, expectedStatus: expectedStatus)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw Error.invalidResponse
        }
    }

    private static func post<Body: Encodable>(
        path: String,
        body: Body,
        expectedStatus: Int
    ) async throws {
        _ = try await send(path: path, body: body, expectedStatus: expectedStatus)
    }

    private static func send<Body: Encodable>(
        path: String,
        body: Body,
        expectedStatus: Int
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }

        if http.statusCode == expectedStatus {
            return data
        }

        throw Error.rejected(userMessage(status: http.statusCode, data: data))
    }

    private static func userMessage(status: Int, data: Data) -> String {
        let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        switch body?.code {
        case "LICENSE_KEY_LIMIT_REACHED":
            return "This license is already activated on the maximum number of Macs."
        case "INACTIVE_LICENSE_KEY":
            return "This license is no longer active."
        case "LICENSE_KEY_NOT_FOUND":
            return "This license key was not found."
        default:
            break
        }

        if let message = body?.message, !message.isEmpty {
            return message
        }

        switch status {
        case 403:
            return "This license is no longer active."
        case 404:
            return "This license key was not found."
        case 422:
            return "This license is already activated on the maximum number of Macs."
        default:
            return "License server returned HTTP \(status)."
        }
    }
}
