# NeedsMe Ai - Phase 1 baseline (2026-11-07)
Tested: live build main-BvTJhAY4 (same file on qa-fixes-2026-10-26) at support897.github.io/needsme/app/, desktop-width browser (phone-width iframe could not sign in: embedded auth blocked, so unverified at 390px).

## Verified (saw it work)
- Door screen shows "NeedsMe Ai", logo intact, Google + Apple + email buttons present.
- Email sign-up with a fresh test user works and lands on Home.
- Pip guide appears after sign-up: "Setup 1 of 5", asks name, Skip guide works, name persisted ("Hello, Tester").
- Bottom tabs Home / Tasks / Projects / AI / More work; Projects and AI (Connect) screens render with empty states; Pip shown on Connect.

## Gaps vs spec (need source to fix)
- Default theme is dark only. Spec s31: Soft White default, Dark Loam, Soft Green, device setting.
- Home has no "Needs your attention / All clear" area, no project progress %, no activity feed (s34).
- Guide is a 5-step setup, not the 7-stop tour of s30 (Home, Projects, AI connections, Rooms, Notes+prompts, Notifications); no Replay seen in Settings yet.
- No visible Notes/Prompts library per project (s33); no 60-second AI setup flow with copyable setup prompt.
- Not tested: Google sign-in, Apple sign-in (need real device), password reset, second-user isolation, offline, 320px, themes.

## Blockers
- Only the compiled bundle is in the repo; no source. Source and iOS project are not on GitHub.
