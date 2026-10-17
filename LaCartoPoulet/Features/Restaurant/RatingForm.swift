import Observation
import SwiftUI

/// "Alors, ce poulet ?": my drumsticks and comment for one restaurant, prefilled when I already rated it.
@Observable @MainActor final class RatingFormModel {
    static let words = ["Sec comme un vieux pneu", "Bof", "Bon poulet", "Croustillant", "Cocorico"]
    static let maxComment = 1000

    var stars = 0
    var comment = ""
    private(set) var existing: MyRating?
    private(set) var isLoaded = false
    private(set) var isWorking = false
    private(set) var error: String?

    private let restaurantID: Int
    private let repository: RatingRepository

    init(restaurantID: Int, repository: RatingRepository) {
        self.restaurantID = restaurantID
        self.repository = repository
    }

    /// "Croustillant" for 4, nil before the first tap.
    var word: String? { (1...5).contains(stars) ? Self.words[stars - 1] : nil }
    var canPublish: Bool { isLoaded && word != nil && comment.count <= Self.maxComment && !isWorking }

    func load() async {
        await run {
            existing = try await repository.myRating(for: restaurantID)
            if let existing {
                stars = existing.stars
                comment = existing.comment ?? ""
            }
            isLoaded = true
        }
    }

    /// True once saved; on failure the form keeps what I typed and shows the error.
    func publish() async -> Bool {
        guard canPublish else { return false }
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        return await run {
            try await repository.save(id: existing?.id, restaurantID: restaurantID, stars: stars,
                                      comment: text.isEmpty ? nil : text)
        }
    }

    func delete() async -> Bool {
        guard let id = existing?.id else { return false }
        return await run { try await repository.delete(id: id) }
    }

    @discardableResult private func run(_ work: () async throws -> Void) async -> Bool {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch is URLError {
            error = "Pas de connexion. Ton avis est gardé, réessaie quand tu as du réseau."
        } catch {
            self.error = "Ça n'a pas marché. Réessaie."
        }
        return false
    }
}

struct RatingForm: View {
    let restaurant: Restaurant
    @State var model: RatingFormModel
    /// Called after a publish or a delete, with true for a publish.
    var onSaved: (Bool) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Alors, ce poulet ?")
                        .font(.display(28, relativeTo: .title))
                        .accessibilityAddTraits(.isHeader)
                    picker
                    VStack(alignment: .trailing, spacing: 4) {
                        TextField("Ton commentaire (facultatif)", text: $model.comment, axis: .vertical)
                            .lineLimit(4...10)
                            .padding(.vertical, 12)
                            .modifier(FieldStyle())
                        let tooLong = model.comment.count > RatingFormModel.maxComment
                        Text("\(model.comment.count)/\(RatingFormModel.maxComment)")
                            .font(.footnote)
                            .foregroundStyle(tooLong ? Color("Comb") : .secondary)
                            .accessibilityLabel(tooLong ? "Commentaire trop long, 1000 caractères maximum"
                                                        : "\(model.comment.count) caractères sur 1000")
                    }
                    Button("Publier") { Task { await finish(publishing: true) } }
                        .buttonStyle(PrimaryButtonStyle(isWorking: model.isWorking))
                        .disabled(!model.canPublish)
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color("Comb"))
                        if !model.isLoaded {
                            Button("Réessayer") { Task { await model.load() } }.foregroundStyle(Color("Feet"))
                        }
                    }
                    if model.existing != nil {
                        Button("Supprimer mon avis", role: .destructive) { confirmsDelete = true }
                            .foregroundStyle(Color("Comb"))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .disabled(model.isWorking)
                    }
                }
                .foregroundStyle(Color("Ink"))
                .padding(16)
                .redacted(reason: model.isLoaded || model.error != nil ? [] : .placeholder)
            }
            .background(Color("Feather"))
            .navigationTitle(restaurant.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
            .confirmationDialog("Supprimer ton avis ?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Supprimer mon avis", role: .destructive) { Task { await finish(publishing: false) } }
            }
        }
        .task { await model.load() }
    }

    /// Five tappable drumsticks, read by VoiceOver as one adjustable control.
    private var picker: some View {
        VStack(spacing: 8) {
            DrumstickRating(value: Double(model.stars), size: 44)
                .overlay {
                    HStack(spacing: 0) {
                        ForEach(1...5, id: \.self) { value in
                            Color.clear.contentShape(Rectangle()).onTapGesture { model.stars = value }
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Note")
                .accessibilityValue(model.word.map { "\(model.stars) sur 5, \($0)" } ?? "Aucune note")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: model.stars = min(model.stars + 1, 5)
                    case .decrement: model.stars = max(model.stars - 1, 1)
                    @unknown default: break
                    }
                }
            if let word = model.word {
                Text("\(word) !")
                    .font(.display(24, relativeTo: .title2))
                    .foregroundStyle(Color("Crispy"))
                    .multilineTextAlignment(.center)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)  // bigger splits "Croustillant" mid-word
                    .accessibilityHidden(true)  // already in the picker's value
            } else {
                Text("Touche un pilon pour noter").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func finish(publishing: Bool) async {
        if await (publishing ? model.publish() : model.delete()) {
            onSaved(publishing)
            dismiss()
        }
    }
}
