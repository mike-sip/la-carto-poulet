import SwiftUI

/// Email → "Recevoir le code" → 6-digit code → nickname the first time.
struct SignInView: View {
    @Bindable var model: AccountViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.step {
            case .email:
                Text("Connecte-toi pour donner ton avis. On t'envoie un code par email, pas besoin de mot de passe.")
                TextField("Adresse email", text: $model.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit { Task { await model.sendCode() } }
                    .modifier(FieldStyle())
                    .focused($focused)
                errorText
                Button("Recevoir le code") { Task { await model.sendCode() } }
                    .buttonStyle(PrimaryButtonStyle(isWorking: model.isWorking))
            case .code:
                Text("Code envoyé à \(model.email). Il arrive en général en quelques secondes.")
                TextField("Code à 6 chiffres", text: $model.code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .modifier(FieldStyle())
                    .focused($focused)
                    .onChange(of: model.code) {
                        if model.code.count == 6 { Task { await model.verify() } }
                    }
                errorText
                Button("Me connecter") { Task { await model.verify() } }
                    .buttonStyle(PrimaryButtonStyle(isWorking: model.isWorking))
                    .disabled(model.code.count != 6)
                HStack {
                    Button("Changer d'adresse") { model.changeEmail() }
                    Spacer()
                    Button("Renvoyer le code") { Task { await model.sendCode() } }
                }
                .font(.subheadline)
                .foregroundStyle(Color("Feet"))
                .frame(minHeight: 44)
            case .nickname:
                Text("Choisis ton pseudo. Il s'affiche avec tes avis ; ton email reste privé.")
                TextField("Pseudo", text: $model.nickname)
                    .textContentType(.nickname)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { Task { await model.saveNickname() } }
                    .modifier(FieldStyle())
                    .focused($focused)
                errorText
                Button("C'est parti") { Task { await model.saveNickname() } }
                    .buttonStyle(PrimaryButtonStyle(isWorking: model.isWorking))
            case .signedIn:
                EmptyView()
            }
        }
        .foregroundStyle(Color("Ink"))
        .disabled(model.isWorking)
        .onAppear { focused = true }
        .onChange(of: model.step) { focused = true }
    }

    @ViewBuilder private var errorText: some View {
        if let error = model.error {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Color("Comb"))
        }
    }
}

private struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color("Feather"), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.4)))
    }
}
