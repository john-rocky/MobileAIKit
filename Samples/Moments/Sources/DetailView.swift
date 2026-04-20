import SwiftUI
import AIKit
import AIKitSpeech

struct DetailView: View {
    @Bindable var store: MomentStore
    let backend: any AIBackend
    let momentId: UUID
    @State private var tts = TextToSpeech(locale: Locale.current)

    var moment: Moment? { store.moment(id: momentId) }

    var body: some View {
        if let moment {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let url = store.imageURL(for: moment),
                       let data = try? Data(contentsOf: url),
                       let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    HStack {
                        Text(moment.title).font(.title).bold()
                        Spacer()
                        Button {
                            Task { await tts.speakUtterance(moment.narrative) }
                        } label: {
                            Image(systemName: "speaker.wave.2.fill").font(.title3)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(moment.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        if let mood = moment.mood {
                            Text("· \(mood)").font(.caption).foregroundStyle(.secondary)
                        }
                        if let place = moment.placeName {
                            Text("· \(place)").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Text(moment.narrative).font(.body)

                    if !moment.tags.isEmpty {
                        HStack {
                            ForEach(moment.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(.tint.opacity(0.15), in: Capsule())
                            }
                        }
                    }

                    if !moment.rows.isEmpty {
                        Divider()
                        ForEach(moment.rows) { row in
                            HStack {
                                Text(row.label).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
                                Text(row.value).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if let transcript = moment.audioTranscript {
                        Divider()
                        Text("Voice note").font(.caption).foregroundStyle(.secondary)
                        Text("“\(transcript)”").italic()
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Not found", systemImage: "questionmark.folder")
        }
    }
}
