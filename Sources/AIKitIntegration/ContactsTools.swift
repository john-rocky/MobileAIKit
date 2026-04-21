import Foundation
import AIKit
#if canImport(Contacts)
import Contacts
#endif

#if canImport(Contacts)
public final class ContactsBridge: @unchecked Sendable {
    public let store = CNContactStore()

    public init() {}

    public func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            store.requestAccess(for: .contacts) { granted, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: granted) }
            }
        }
    }

    public func searchTool() -> any Tool {
        let spec = ToolSpec(
            name: "search_contacts",
            description: "Search the user's contacts by name.",
            parameters: .object(
                properties: ["query": .string(description: "Name to search.")],
                required: ["query"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let query: String }
        struct Out: Encodable {
            let name: String
            let phones: [String]
            let emails: [String]
        }
        return TypedTool(spec: spec) { (args: Args) async throws -> [Out] in
            // CNContactStore is not Sendable; construct one per invocation so
            // the @Sendable TypedTool closure doesn't capture shared state.
            let store = CNContactStore()
            let predicate = CNContact.predicateForContacts(matchingName: args.query)
            let keys = [
                CNContactGivenNameKey, CNContactFamilyNameKey,
                CNContactPhoneNumbersKey, CNContactEmailAddressesKey
            ] as [CNKeyDescriptor]
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
            return contacts.map { c in
                Out(
                    name: "\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces),
                    phones: c.phoneNumbers.map { $0.value.stringValue },
                    emails: c.emailAddresses.map { $0.value as String }
                )
            }
        }
    }
}
#endif
