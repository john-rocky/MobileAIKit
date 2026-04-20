import SwiftUI
import UniformTypeIdentifiers

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIDocumentPickerButton<Label: View>: View {
    public let contentTypes: [UTType]
    public let allowsMultiple: Bool
    public let onPicked: ([URL]) -> Void
    public let label: () -> Label

    @State private var isPresented = false

    public init(
        contentTypes: [UTType] = [.pdf, .plainText, .image, .audio, .movie, .data],
        allowsMultiple: Bool = false,
        onPicked: @escaping ([URL]) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.contentTypes = contentTypes
        self.allowsMultiple = allowsMultiple
        self.onPicked = onPicked
        self.label = label
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            label()
        }
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: allowsMultiple
        ) { result in
            if case .success(let urls) = result {
                onPicked(urls)
            }
        }
    }
}
