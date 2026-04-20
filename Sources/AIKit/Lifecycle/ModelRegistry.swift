import Foundation

public actor ModelRegistry {
    public static let shared = ModelRegistry()
    private var descriptors: [String: ModelDescriptor] = [:]

    public init() {}

    public func register(_ descriptor: ModelDescriptor) {
        descriptors[descriptor.id] = descriptor
    }

    public func register(contentsOf descriptors: [ModelDescriptor]) {
        for d in descriptors { register(d) }
    }

    public func unregister(_ id: String) {
        descriptors.removeValue(forKey: id)
    }

    public func descriptor(id: String) -> ModelDescriptor? {
        descriptors[id]
    }

    public func descriptor(name: String) -> ModelDescriptor? {
        descriptors.values.first { $0.name == name }
    }

    public func all() -> [ModelDescriptor] {
        Array(descriptors.values)
    }

    public func byModality(_ modality: ModelModality) -> [ModelDescriptor] {
        descriptors.values.filter { $0.modality == modality }
    }

    public func byFormat(_ format: ModelFormat) -> [ModelDescriptor] {
        descriptors.values.filter { $0.format == format }
    }
}

public extension ModelRegistry {
    static func builtInSeed() -> [ModelDescriptor] {
        []
    }
}
