import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIFormFillView: View {
    public struct Field: Identifiable, Hashable, Sendable {
        public let id: String
        public let label: String
        public let hint: String?
        public let required: Bool

        public init(id: String, label: String, hint: String? = nil, required: Bool = true) {
            self.id = id
            self.label = label
            self.hint = hint
            self.required = required
        }
    }

    public let fields: [Field]
    public let backend: any AIBackend
    public let onSubmit: ([String: String]) -> Void

    @State private var source: String = ""
    @State private var values: [String: String] = [:]
    @State private var isFilling: Bool = false
    @State private var error: String?

    public init(fields: [Field], backend: any AIBackend, onSubmit: @escaping ([String: String]) -> Void) {
        self.fields = fields
        self.backend = backend
        self.onSubmit = onSubmit
    }

    public var body: some View {
        Form {
            Section("Paste source text (optional)") {
                TextField("Source", text: $source, axis: .vertical)
                    .lineLimit(3...8)
                Button(isFilling ? "Filling…" : "Autofill with AI") { Task { await fill() } }
                    .disabled(source.isEmpty || isFilling)
            }
            Section("Fields") {
                ForEach(fields) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.label).font(.caption).foregroundStyle(.secondary)
                        TextField(field.hint ?? field.label, text: binding(for: field.id))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button("Submit") { onSubmit(values) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(get: { values[id] ?? "" }, set: { values[id] = $0 })
    }

    private func fill() async {
        isFilling = true
        defer { isFilling = false }
        error = nil
        do {
            var props: [String: JSONSchema] = [:]
            var required: [String] = []
            for f in fields {
                props[f.id] = .string(description: f.hint ?? f.label)
                if f.required { required.append(f.id) }
            }
            let schema: JSONSchema = .object(properties: props, required: required)
            struct GenericBag: Decodable { let extra: [String: String]? }
            let value: [String: String] = try await AIKit.extract(
                [String: String].self,
                from: source,
                schema: schema,
                instruction: "Extract the fields from the source text. Return a flat JSON object.",
                backend: backend
            )
            for (k, v) in value { values[k] = v }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
