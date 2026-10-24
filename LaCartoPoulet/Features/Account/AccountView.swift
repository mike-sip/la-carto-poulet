import SwiftUI

/// "Mon compte": the sign-in steps when signed out, nickname, email and sign-out when signed in.
struct AccountView: View {
    @Bindable var model: AccountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false
    @State private var suggests = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isSignedIn {
                        LabeledContent("Pseudo", value: model.nickname)
                        LabeledContent("Email", value: model.email)
                        Text("Ton email n'est jamais montré aux autres.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Suggérer un resto manquant") { suggests = true }
                            .foregroundStyle(Color("Feet"))
                            .frame(minHeight: 44)
                        blockedList
                        if let error = model.error {
                            Text(error).font(.subheadline).foregroundStyle(Color("Comb"))
                        }
                        Button("Se déconnecter") { Task { await model.signOut() } }
                            .foregroundStyle(Color("Feet"))
                            .frame(minHeight: 44)
                        Button("Supprimer mon compte", role: .destructive) { confirmsDelete = true }
                            .foregroundStyle(Color("Comb"))
                            .frame(minHeight: 44)
                            .disabled(model.isWorking)
                    } else {
                        SignInView(model: model)
                    }
                    HStack(spacing: 4) {
                        Text("Données")
                        OSMCredit()
                    }
                    .font(.footnote)
                    .padding(.top, 16)
                }
                .padding(16)
            }
            .background(Color("Feather"))
            .confirmationDialog("Supprimer ton compte ?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Supprimer mon compte", role: .destructive) { Task { await model.deleteAccount() } }
            } message: {
                Text("Ton pseudo, tes avis, tes signalements, tes blocages et tes suggestions seront effacés. C'est définitif.")
            }
            .sheet(isPresented: $suggests) { SuggestSheet(account: model) }
            .scrollDismissesKeyboard(.interactively)
            .task(id: model.isSignedIn) { await model.loadBlocks() }
            .navigationTitle("Mon compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
        }
    }

    private var blockedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Utilisateurs bloqués").font(.headline).accessibilityAddTraits(.isHeader)
            if model.blocked.isEmpty {
                Text("Aucun utilisateur bloqué").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(model.blocked) { user in
                HStack {
                    Text(user.nickname)
                    Spacer()
                    Button("Débloquer") { Task { await model.unblock(user) } }
                        .foregroundStyle(Color("Feet"))
                        .frame(minHeight: 44)
                        .accessibilityLabel("Débloquer \(user.nickname)")
                }
            }
        }
        .padding(.top, 8)
    }
}
