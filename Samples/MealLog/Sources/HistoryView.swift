import SwiftUI
import AIKit
import AIKitSpeech

struct HistoryView: View {
    @Bindable var store: MealStore
    let backend: any AIBackend
    @State private var tts = TextToSpeech()

    var today: Date { Calendar.current.startOfDay(for: Date()) }
    var totals: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        store.dailyTotals(on: today)
    }

    var body: some View {
        List {
            Section("Today") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(totals.calories) kcal").font(.largeTitle).bold()
                    HStack(spacing: 12) {
                        macro("P", Int(totals.protein), .pink)
                        macro("C", Int(totals.carbs), .orange)
                        macro("F", Int(totals.fat), .purple)
                    }
                }
                Button {
                    Task {
                        let summary = "Today you logged \(totals.calories) calories so far, with \(Int(totals.protein)) grams of protein, \(Int(totals.carbs)) grams of carbs, and \(Int(totals.fat)) grams of fat."
                        await tts.speakUtterance(summary)
                    }
                } label: { Label("Read today's totals", systemImage: "speaker.wave.2.fill") }
            }
            Section("Logged") {
                if store.meals.isEmpty {
                    ContentUnavailableView("No meals yet", systemImage: "fork.knife")
                }
                ForEach(store.meals) { meal in
                    row(meal)
                }
                .onDelete { indexSet in
                    Task { for idx in indexSet { try? await store.delete(store.meals[idx]) } }
                }
            }
        }
        .navigationTitle("Meal log")
    }

    func macro(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(value)g").bold().foregroundStyle(color)
        }.frame(maxWidth: .infinity)
        .padding(6)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    func row(_ meal: Meal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            thumb(meal)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(meal.kind.emoji) \(meal.title)").font(.headline)
                Text("\(meal.estimatedCalories) kcal · \(meal.dishes.map(\.name).joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(meal.date, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await tts.speakUtterance(meal.spokenSummary) }
            } label: {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    func thumb(_ meal: Meal) -> some View {
        if let url = store.imageURL(for: meal),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: "fork.knife")
                .frame(width: 56, height: 56)
                .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
