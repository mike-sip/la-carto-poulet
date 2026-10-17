import SwiftUI

/// "Mon compte": the sign-in steps when signed out, nickname, email and sign-out when signed in.
struct AccountView: View {
    @Bindable var model: AccountViewModel
    @Environment(\.dismiss) private var dismiss

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
                        blockedList
                        if let error = model.error {
                            Text(error).font(.subheadline).foregroundStyle(Color("Comb"))
                        }
                        Button("Se déconnecter") { Task { await model.signOut() } }
                            .foregroundStyle(Color("Feet"))
                            .frame(minHeight: 44)
                    } else {
                        SignInView(model: model)
                    }
                }
                .padding(16)
            }
            .background(Color("Feather"))
            .task(id: model.isSignedIn) { await model.loadBlocks() }
            .navigationTitle("Mon compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
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
