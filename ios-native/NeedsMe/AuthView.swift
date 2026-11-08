import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var email = ""
    @State private var password = ""
    @State private var signingUp = true      // sign up is the first thing people see
    @State private var showEmail = false

    func submit() {
        guard !store.busy, !email.isEmpty, password.count >= 6 else { return }
        Task { if signingUp { await store.signUp(email, password) } else { await store.signIn(email, password) } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image("pip-welcome").resizable().scaledToFit().frame(width: 112, height: 112).clipShape(Circle())
                    .accessibilityHidden(true)
                Text(signingUp ? "Welcome to NeedsMe Ai" : "Welcome back")
                    .font(.system(.title, design: .rounded).weight(.heavy)).foregroundColor(p.ink).multilineTextAlignment(.center)
                Text(signingUp ? "All your AIs and projects in one calm place. Pick how to start." : "Pick how you signed up.")
                    .foregroundColor(p.soft).multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    SignInWithAppleButton(signingUp ? .signUp : .signIn,
                        onRequest: { store.prepareApple($0) },
                        onCompletion: { r in Task { await store.finishApple(r) } })
                        .signInWithAppleButtonStyle(p.isDark ? .white : .black)
                        .frame(height: 52).clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("appleButton")

                    Button { Task { await store.googleDoor() } } label: {
                        HStack { Image(systemName: "g.circle.fill"); Text(signingUp ? "Sign up with Google" : "Sign in with Google").fontWeight(.semibold) }
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(p.card).foregroundColor(p.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.line, lineWidth: 1.5))
                    }.accessibilityIdentifier("googleButton")

                    Button { withAnimation { showEmail.toggle() } } label: {
                        HStack { Image(systemName: "envelope.fill"); Text(signingUp ? "Sign up with email" : "Sign in with email").fontWeight(.semibold) }
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(p.card).foregroundColor(p.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.line, lineWidth: 1.5))
                    }.accessibilityIdentifier("emailButton")
                }

                if showEmail {
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
                    }.foregroundColor(p.ink).transition(.opacity)
                }

                if store.busy { ProgressView().tint(p.accent) }
                if !store.message.isEmpty {
                    Text(store.message).font(.footnote.weight(.medium)).foregroundColor(p.isDark ? Color(red: 1, green: 0.62, blue: 0.62) : Color(red: 0.7, green: 0.1, blue: 0.1))
                        .multilineTextAlignment(.center).accessibilityIdentifier("authMessage")
                }

                Button(signingUp ? "Already have an account? Sign in" : "New here? Make an account") { signingUp.toggle(); store.message = "" }
                    .foregroundColor(p.ink).font(.subheadline.weight(.semibold)).accessibilityIdentifier("switchMode")
                Link("Privacy policy", destination: URL(string: "https://support897.github.io/needsme/privacy.html")!).font(.footnote).foregroundColor(p.soft)
            }.padding(24)
        }.scrollDismissesKeyboard(.interactively)
    }
}
