import SwiftUI

struct AuthView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var email = ""
    @State private var password = ""
    @State private var creating = false
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("pip-welcome").resizable().scaledToFit().frame(width: 96, height: 96).clipShape(Circle())
                Text("NeedsMe Ai").font(.system(.largeTitle, design: .rounded).weight(.heavy)).foregroundColor(p.ink)
                Text("Sign in or make your account").foregroundColor(p.soft)
                VStack(spacing: 12) {
                    TextField("you@example.com", text: $email)
                        .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                        .padding().background(p.card).clipShape(RoundedRectangle(cornerRadius: 14))
                    SecureField("Password", text: $password)
                        .padding().background(p.card).clipShape(RoundedRectangle(cornerRadius: 14))
                }.foregroundColor(p.ink)
                if !store.message.isEmpty { Text(store.message).font(.footnote).foregroundColor(.red).multilineTextAlignment(.center) }
                Button(creating ? "Make my account" : "Sign in") {
                    busy = true
                    Task { if creating { await store.signUp(email, password) } else { await store.signIn(email, password) }; busy = false }
                }.buttonStyle(PrimaryButton()).disabled(busy || email.isEmpty || password.count < 6)
                Button(creating ? "I already have an account" : "New here? Make an account") { creating.toggle(); store.message = "" }
                    .foregroundColor(p.ink).font(.subheadline.weight(.semibold))
                Button("Try without an account") { busy = true; Task { await store.guest(); busy = false } }
                    .buttonStyle(SoftButton()).disabled(busy).accessibilityIdentifier("guestButton")
                if !creating { Button("Forgot password?") { Task { await store.reset(email) } }.font(.footnote).foregroundColor(p.soft) }
                Link("Privacy policy", destination: URL(string: "https://support897.github.io/needsme/privacy.html")!).font(.footnote).foregroundColor(p.soft)
            }.padding(24)
        }
    }
}
