import Foundation
import AIKit

enum StructuredExtraction {
    struct Contact: Codable, Hashable {
        let name: String
        let email: String?
        let phone: String?
        let company: String?
    }

    static let schema: JSONSchema = .object(
        properties: [
            "name": .string(description: "Full name"),
            "email": .string(format: "email"),
            "phone": .string(),
            "company": .string()
        ],
        required: ["name"]
    )

    static func extractContact(text: String, backend: any AIBackend) async throws -> Contact {
        try await AIKit.extract(
            Contact.self,
            from: text,
            schema: schema,
            instruction: "Extract contact details from the text.",
            backend: backend
        )
    }
}
