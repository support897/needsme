# POLAR-APPLE-FIX — why Apple sign-in fails on build 343, and the fix plan

Written 2026-11-17 ~12:00 (Brisbane). Tree read: ~/nm341-build, branch qa-fixes-2026-10-26, HEAD 216e24a (build 343).
Status: DIAGNOSIS + PLAN ONLY. No code changed. Nothing pushed. Nothing shipped.

## 1. Short answer

Most likely cause (proven in part, see section 4): **the shipped app has no "Sign in with Apple" entitlement.**
The ship workflow (.github/workflows/testflight.yml) builds an UNSIGNED archive (CODE_SIGNING_ALLOWED=NO), then
runs `xcodebuild -exportArchive` to let Apple sign it. Export only keeps entitlements that are already inside a
signature. An unsigned archive has none. So the app that reaches the phone is signed without
`com.apple.developer.applesignin`, and iOS refuses the Apple request (ASAuthorizationError 1000).
Google does not need an entitlement, so Google works. That matches Ilse's test exactly.
This also fits history: Apple has NEVER been proven on any build made this way (POLAR-FINISH.md: "Fresh Apple sign-up complete: COULD NOT CHECK").

Second cause, in code (certain): the Apple door hides what went wrong and breaks the "quiet cancel" rule (section 3).

What I could NOT verify: the exact words Ilse saw on her phone, and the signing of the actual 343 file in TestFlight
(that file is not on this Mac; the signing key is only in the repo secrets). See section 6.

## 2. How Apple sign-in runs today (read from code)

1. AuthView.swift:23 draws SwiftUI `SignInWithAppleButton(.continue)`; accessibility id `appleButton`.
2. onRequest -> `Store.prepareApple` (Store.swift:298): makes a random 32-char nonce, keeps it in memory, asks for
   scopes fullName + email, sends SHA-256 of the nonce to Apple.
3. iOS shows the Apple sheet. This step needs the app to carry the applesignin entitlement.
   Entitlement file is right (NeedsMe.entitlements, `com.apple.developer.applesignin = Default`; project.yml:28 too).
4. onCompletion -> `Store.finishApple` (Store.swift:303):
   - failure: code 1001 (canceled) -> shows "Apple sign-in was cancelled."; any other error -> shows
     "Apple sign-in did not finish. Try email for now." (the real error is thrown away).
   - success: reads identityToken -> `OAuthProvider.appleCredential(withIDToken:, rawNonce:, fullName:)`
     -> `Auth.auth().signIn(with:)` through `run{}` (errors shown with Firebase's own words).
5. Firebase checks the token. For the native route the token audience is the bundle ID
   `shop.ilseplacencia.needsme`; FirebaseBoot sets that same bundleID (NeedsMeApp.swift:11-16). Matches.
6. Signed in -> Store listener sets `user`; RootView shows the app. Same path Google uses, and Google works.

## 3. Where a fresh sign-up can break (each link, with verdict)

| # | Link | Verdict |
|---|------|---------|
| A | App carries the applesignin entitlement after export | **Likely BROKEN** (unsigned archive; section 4) |
| B | App ID `shop.ilseplacencia.needsme` has Sign in with Apple switched on, as the primary App ID | UNVERIFIED (Apple Developer portal; needs Ilse's login) |
| C | Apple's own service completes a first-time sign-up | UNVERIFIED. Apple forum threads from 14-17 Nov 2026 report first-time sign-ups failing with error 1000 on other apps too. Could be a side factor. Not proven to apply here. |
| D | Firebase has the Apple provider enabled | **OK, checked.** One harmless probe with a fake Apple token returned "Unable to parse the ID Token" (provider recognised). A control provider that is off returned "Invalid credential or provider id". No password, key or token stored. |
| E | Nonce, audience, rawNonce | OK by reading. Standard pattern, bundle ID matches. |
| F | Cancel comes back quietly | **BROKEN in code.** Cancel shows the line "Apple sign-in was cancelled." The handout says no error text on cancel. |
| G | Failure is readable | **BROKEN in code.** Every non-cancel failure becomes "Try email for now." The real code is lost, so nobody (me, Ilse, a tester) can tell A from B from C. |
| H | `isDoorCancel` (Store.swift:317-319) treats AuthorizationError **1000** as a cancel. 1000 is "unknown", the very error A produces. Cancel is 1001. | Latent bug. It would hide a real failure if Apple ever used that helper. Fix with the rest. |
| I | After sign-up: private-relay email, name only given the first time | Low risk. App only shows `user.email` as text. Google users go through the same screens. Re-check on the fresh run. |

## 4. Proof I did (scratch only, nothing in the repo touched)

- Built the same unsigned device archive the workflow builds (copy in /tmp/nm-apple, own derived-data folder).
  Result: `codesign -d --entitlements` on NeedsMe.app says **"code object is not signed at all"**. No entitlements in it.
- Same app, ad-hoc signed with `codesign -f -s - --entitlements NeedsMe/NeedsMe.entitlements`:
  the applesignin entitlement is now present and readable.
- The workflow has no codesign step for the app (it only strips framework signatures), so export gets no entitlements to keep.
- Outside sources: Apple developer forums thread 686345 (unsigned archive then export; missing push entitlement ITMS-90078);
  forums thread 756119 (CI team signs the app with codesign before export to keep entitlements);
  tauri-apps issue 15663 ("exportArchive preserves only entitlements already present in a signature"; ad-hoc signing is enough).
  Other forum threads (e.g. 839521) show the same symptom (error 1000, Google fine) for apps with a bad App ID or profile.
- Not proven: that the exact 343 file lacks the entitlement. That needs the real exported file or Ilse's phone message. It is a strong, consistent explanation, not a read-back.

## 5. Fix plan (one small change at a time, each tested)

Step 1 — Ship workflow (the real fix). In testflight.yml, between "Set build number in archive" and "Export":
  - ad-hoc sign the main app only, with its entitlements file:
    `codesign -f -s - --entitlements ios-native/NeedsMe/NeedsMe.entitlements $A/Products/Applications/NeedsMe.app`
    (not --deep; frameworks stay as they are, export re-signs everything with the real certificate).
  - then print `codesign -d --entitlements` and FAIL the run if `com.apple.developer.applesignin` is missing.
  - upgrade of the proof: export to an .ipa first (destination export), unzip it, read the entitlements and the embedded
    profile, fail if applesignin is missing, then upload. If Apple's export rejects the ad-hoc signature, fall back to
    signing the archive with the Apple Distribution certificate from the same Admin key flow. Two tries max, then stop and re-plan.
Step 2 — Swift, Apple door only (Store.swift):
  - quiet cancel: 1001 = no message, door stands clean (same as Google).
  - fix `isDoorCancel`: Apple cancel is 1001, never 1000.
  - keep Firebase's real words for failures, and for error 1000 show a short plain line plus the code, e.g.
    "Apple could not start (1000)." so the next test tells us which link broke.
Step 3 — Local checks before any ship: the existing test17 (Apple door opens and dismisses clean) must still pass, and a new
  tiny check that cancel leaves no error line. Use ONE simulator, not the paused thread's files.
Step 4 — Ship as the next build, number stamped by hand above 343 (suggest 344). Read back from App Store Connect: VALID, first in app list, first in both tester groups.
Step 5 — THE ONLY PROOF THAT COUNTS: a FRESH Apple sign-up on that build, on a real phone, as a new user does it, to the end.
  Cancel once first: it must come back quietly, no error page, no Firebase error page.
  Then complete. Team Apple account only. Codes never in chat or files. Then Google and email fresh proofs in the same round.
Step 6 — If step 5 still fails with 1000 after the entitlement is proven present: go to links B and C (App ID capability in the
  Developer portal; Apple-side outage) with the real code from step 2 in hand.

## 6. Open items I need (named, with owner)

- Ilse: the exact words or screen she saw on the phone (a) the Apple sheet never opened, (b) sheet opened then "Sign Up Not Completed", or (c) the app showed "Apple sign-in did not finish. Try email for now." (a) and (c) point at link A. (b) points at B or C. One line from her sharpens this a lot.
- Ilse / whoever holds the Apple Developer login: confirm App ID shop.ilseplacencia.needsme shows Sign in with Apple ON (link B). I cannot sign in there.
- Real phone + team Apple account for the fresh sign-up (step 5). I do not hold either.

## 7. Does this ride the paused end-to-end thread? — NO

- The fix is two small edits in THIS tree (one workflow file, one Swift file) and one ship. It does not need the paused
  thread's files, simulator, or test pass, and I will not touch them.
- Order: it ships FIRST, as its own build above 343, and does not wait for the design approval (design waits for Ilse; Apple does not).
- Collision rule: I have pushed nothing. When Ilse says go, I push one commit to qa-fixes-2026-10-26. If the paused thread wakes
  at 18:00 before that, its first action must be to pull this branch tip, so the Apple fix commit goes first and nothing
  overwrites it. Its fresh Apple/Google/email proofs then run on the fixed build, not on 343.
- Asked of the Boss desk: say the word and I push and ship. I will not push or ship without it.
