import SwiftUI

/// "Signaler cet avis": pick a reason, then a thank-you. Three reports hide the comment.
struct ReportSheet: View {
    let rating: Rating
    let repository: RatingRepository

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var isDone = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if isDone {
                    Text("Merci, on s'en occupe !")
                        .font(.display(26, relativeTo: .title2))
                        .accessibilityAddTraits(.isHeader)
                    Text("Le commentaire disparaît dès que 3 personnes le signalent.")
                    Button("Fermer") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("Pourquoi signaler l'avis de \(rating.nickname) ?").font(.headline)
                    ForEach(ReportReason.allCases) { reason in
                        Button(reason.label) { Task { await send(reason) } }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color("Feet"))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Feet"), lineWidth: 2))
                            .disabled(isWorking)
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color("Comb"))
                    }
                }
                Spacer()
            }
            .foregroundStyle(Color("Ink"))
            .padding(16)
            .background(Color("Feather"))
            .navigationTitle("Signaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isDone {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                }
            }
        }
    }

    private func send(_ reason: ReportReason) async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await repository.report(ratingID: rating.id, reason: reason)
            isDone = true
        } catch is URLError {
            error = "Pas de connexion. Réessaie quand tu as du réseau."
        } catch {
            self.error = "Ça n'a pas marché. Réessaie."
        }
    }
}
