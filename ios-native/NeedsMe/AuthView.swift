import SwiftUI
import AuthenticationServices

/// The door. The first page holds only the Google button, the Apple button and one small email button.
/// The email button opens a separate email page. The door set is Google, Apple, and email with her own password.
struct AuthView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var signingUp = true      // sign up is the first thing people see

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Spacer()
                SignInWithAppleButton(.continue,
                    onRequest: { store.prepareApple($0) },
                    onCompletion: { r in Task { await store.finishApple(r) } })
                    .signInWithAppleButtonStyle(p.isDark ? .white : .black)
                    .frame(height: 52).clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("appleButton")

                Button { Task { await store.googleDoor() } } label: {
                    HStack { Image(systemName: "g.circle.fill"); Text("Continue with Google").fontWeight(.semibold) }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(p.card).foregroundColor(p.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.line, lineWidth: 1.5))
                }.accessibilityIdentifier("googleButton")

                NavigationLink {
                    EmailDoorView(signingUp: $signingUp)
                } label: {
                    HStack(spacing: 6) { Image(systemName: "envelope.fill"); Text("Email").fontWeight(.semibold) }
                        .font(.subheadline).foregroundColor(p.ink)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(p.chip).clipShape(Capsule())
                }.accessibilityIdentifier("emailButton")

                if !store.message.isEmpty {
                    Text(store.message).font(.footnote.weight(.medium)).foregroundColor(p.isDark ? Color(red: 1, green: 0.62, blue: 0.62) : Color(red: 0.7, green: 0.1, blue: 0.1))
                        .multilineTextAlignment(.center).accessibilityIdentifier("authMessage")
                }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(p.bg)
        }
    }
}

/// The email page: email, her own password, sign up and sign in with the mode switch. Swipe back or the back arrow returns to the door.
struct EmailDoorView: View {
    @Binding var signingUp: Bool
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var email = ""
    @State private var password = ""

    func submit() {
        guard !store.busy, !email.isEmpty, password.count >= 6 else { return }
        Task { if signingUp { await store.signUp(email, password) } else { await store.signIn(email, password) } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TextField("you@example.com", text: $email)
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                    .padding().background(p.card).clipShape(RoundedRectangle(cornerRadius: 14))
                SecureField("Password (6+ letters)", text: $password)
                    .submitLabel(.go).onSubmit { submit() }
                    .padding().background(p.card).clipShape(RoundedRectangle(cornerRadius: 14))
                Button(signingUp ? "Make my account" : "Sign in") { submit() }.buttonStyle(PrimaryButton()).disabled(store.busy || email.isEmpty || password.count < 6)
                    .accessibilityIdentifier("emailSubmit")
                if !signingUp { Button("Forgot password?") { Task { await store.reset(email) } }.font(.footnote).foregroundColor(p.soft) }
                if store.busy { ProgressView().tint(p.accent) }
                if !store.message.isEmpty {
                    Text(store.message).font(.footnote.weight(.medium)).foregroundColor(p.isDark ? Color(red: 1, green: 0.62, blue: 0.62) : Color(red: 0.7, green: 0.1, blue: 0.1))
                        .multilineTextAlignment(.center).accessibilityIdentifier("authMessage")
                }
                Button(signingUp ? "Already have an account? Sign in" : "New here? Make an account") { signingUp.toggle(); store.message = "" }
                    .foregroundColor(p.ink).font(.subheadline.weight(.semibold)).accessibilityIdentifier("switchMode")
            }
            .foregroundColor(p.ink).padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(p.bg)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.message = "" }
    }
}
