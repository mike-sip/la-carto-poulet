import SwiftUI

/// "Suggérer un resto": name, address and an optional note, sent to the admin who adds it to OpenStreetMap.
struct SuggestSheet: View {
    @Bindable var account: AccountViewModel
    var repository: RestaurantRepository = SupabaseRestaurantRepository()
    @State var name = ""
    @State private var address = ""
    @State private var note = ""

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var isDone = false
    @State private var error: String?

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool {
        trimmed(name).count >= 2 && trimmed(address).count >= 2 && note.count <= 500 && !isWorking
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isDone {
                        Text("Merci, c'est noté !")
                            .font(.display(26, relativeTo: .title2))
                            .accessibilityAddTraits(.isHeader)
                        Text("On vérifie le resto, puis on l'ajoute à OpenStreetMap. Il apparaîtra sur la carte d'ici un mois environ.")
                        Button("Fermer") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else if !account.isSignedIn {
                        SignInView(model: account)
                    } else {
                        Text("Un resto spécialisé poulet manque sur la carte ? Dis-nous où il est.")
                        TextField("Nom du resto", text: $name)
                            .textContentType(.organizationName)
                            .modifier(FieldStyle())
                        TextField("Adresse (rue et ville)", text: $address)
                            .textContentType(.fullStreetAddress)
                            .modifier(FieldStyle())
                        TextField("Ce qu'on y mange (facultatif)", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(.vertical, 12)
                            .modifier(FieldStyle())
                        if note.count > 500 {
                            Text("500 caractères maximum.").font(.footnote).foregroundStyle(Color("Comb"))
                        }
                        Button("Envoyer") { Task { await send() } }
                            .buttonStyle(PrimaryButtonStyle(isWorking: isWorking))
                            .disabled(!canSend)
                        if let error {
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color("Comb"))
                        }
                    }
                }
                .padding(16)
            }
            .foregroundStyle(Color("Ink"))
            .background(Color("Feather"))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Suggérer un resto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isDone {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                }
            }
        }
    }

    private func send() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        let note = trimmed(note)
        do {
            try await repository.suggest(name: trimmed(name), address: trimmed(address), note: note.isEmpty ? nil : note)
            isDone = true
        } catch is URLError {
            error = "Pas de connexion. Réessaie quand tu as du réseau."
        } catch {
            self.error = "Ça n'a pas marché. Réessaie."
        }
    }
}
