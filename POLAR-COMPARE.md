# POLAR-COMPARE.md (build 342 pass)

## JOB ONE - THE DOORS (fault file POLAR-FAULT-DOOR-341.md)

### How each door worked in build 341 (read from ios-native/NeedsMe/Store.swift, AuthView.swift)
- Google door: Store.googleDoor() used Firebase OAuthProvider(providerID:"google.com").getCredentialWith(nil).
  This is the generic web IdP flow: the app opens an auth web session to
  needs-me-480ea.firebaseapp.com/__/auth/handler (Firebase's redirect handler), which keeps its start state in
  the browser's sessionStorage, goes to Google, and returns to the same handler. On a real iPhone the return leg
  lost that state -> the exact "missing initial state ... signInWithRedirect ... storage-partitioned" page.
- Apple door: SignInWithAppleButton + ASAuthorizationController (NATIVE system sheet) -> identity token + nonce ->
  OAuthProvider.appleCredential -> Auth.signIn(with:). By code this door never opens a web page, so code alone
  does not explain the firebaseapp.com page on Apple. Her Apple failure is NOT reproducible from code reading.
  Real-phone Apple = Could not check (no phone access) unless driven on simulator.
- Email: createUser/signIn(withEmail:), no web leg.

### Research on the named error
- "missing initial state" is thrown by the firebaseapp.com /__/auth/handler when sessionStorage is partitioned
  or cleared between start and return (iOS in-app auth sessions, ITP, Chrome storage partitioning). Documented
  cures: (a) native provider SDK, pass its ID token to Firebase as a credential, no web handler; (b) self-host the
  handler on the app's own domain. Only (a) fits an iOS app.
- Chosen route: native Google Sign-In SDK (GoogleSignIn-iOS 8.x) -> GoogleAuthProvider.credential(idToken,
  accessToken) -> Firebase. Needs only what the tree holds: iOS client ID in FirebaseOptions and the reversed
  client ID URL scheme in Info.plist. onOpenURL hands the return URL to the SDK. Cancel = GIDSignInError.canceled
  -> quiet return. Apple stays native.
