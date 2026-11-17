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
            VStack(spacing: 0) {
                Spacer(minLength: 20)
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color.sproutPale, Color.sproutPale.opacity(0)], center: .center, startRadius: 0, endRadius: 125))
                        .frame(width: 250, height: 250)
                    Circle().stroke(Color.sprout.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [5, 5])).frame(width: 198, height: 198)
                    PipArt(pose: .welcome, height: 162).accessibilityIdentifier("doorPip")
                    AIFace(label: "Claude", size: 46).offset(x: -92, y: -62)
                    AIFace(label: "Gemini", size: 46).offset(x: 96, y: -34)
                    AIFace(label: "ChatGPT", size: 46).offset(x: 62, y: 84)
                }.frame(height: 250)
                HStack(spacing: 10) {
                    SproutMark(size: 34)
                    Text("NeedsMe Ai").font(.system(size: 34, weight: .heavy)).tracking(-0.6).foregroundColor(.loam)
                        .accessibilityIdentifier("doorWordmark")
                }.padding(.top, 6)
                Text("All your AIs, in one room.\nWe tell you when something needs you.")
                    .font(.system(size: 16)).foregroundColor(.muted).multilineTextAlignment(.center).lineSpacing(3)
                    .padding(.top, 10).accessibilityIdentifier("doorPromise")
                Spacer(minLength: 24)
                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue,
                        onRequest: { store.prepareApple($0) },
                        onCompletion: { r in Task { await store.finishApple(r) } })
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 54).clipShape(RoundedRectangle(cornerRadius: 19))
                        .shadow(color: Color.loam.opacity(0.3), radius: 13, y: 7)
                        .accessibilityIdentifier("appleButton")

                    Button { Task { await store.googleDoor() } } label: {
                        HStack(spacing: 10) {
                            ZStack { Circle().fill(Color.loam); Text("G").font(.system(size: 11, weight: .heavy)).foregroundColor(.bone) }.frame(width: 24, height: 24)
                            Text("Continue with Google").font(.system(size: 17, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Color.cardTone).foregroundColor(.loam)
                        .clipShape(RoundedRectangle(cornerRadius: 19))
                        .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color(hex: 0xDDD6C6), lineWidth: 1.5))
                    }.accessibilityIdentifier("googleButton")

                    NavigationLink {
                        EmailDoorView(signingUp: $signingUp)
                    } label: {
                        HStack(spacing: 8) { Image(systemName: "envelope"); Text("Email").fontWeight(.bold) }
                            .font(.system(size: 15)).foregroundColor(.loam)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Color.loam.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 20))
                    }.accessibilityIdentifier("emailButton")

                    if !store.message.isEmpty {
                        Text(store.message).font(.footnote.weight(.medium)).foregroundColor(Color(red: 0.7, green: 0.1, blue: 0.1))
                            .multilineTextAlignment(.center).accessibilityIdentifier("authMessage")
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "lock").font(.system(size: 12))
                        Text("Your AIs are yours alone. Never shared.").font(.system(size: 12))
                    }.foregroundColor(.muted).padding(.top, 2)
                }.padding(.horizontal, 24)
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DoorBackdrop().ignoresSafeArea())
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
