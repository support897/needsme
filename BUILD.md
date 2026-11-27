# NeedsMe desktop (Mac and Windows) source

Taken out of the v1.4.0 release (app.asar), then fixed for v1.5.0. Electron 45.4.1.

## v1.5.0 changes
- One shared AI list for the whole Needs Me account (`nm-shared.js`, Firestore `users/{uid}/settings/aiaccounts`), the same on Android, iPhone, web, Mac and Windows. Old phone and computer lists are brought in once.
- Pop-ups and new-window links open as real windows in the same saved login (sign-in pop-ups work).
- Alerts: title is "AI · account name", the text is the AI's own last reply, once per reply.
- Per-AI switches: pull chats and projects, use for Needs Me, show updates. Description up to 300 characters.
- "+" list split into "Already logged in" and "Not logged in yet".
- AI replies are added to Updates.

## Test
`node test-nm-shared.js`

## Build (how v1.5.0 was made on Linux)
Mac: put the new app.asar into the v1.4.0 NeedsMe.app, update ElectronAsarIntegrity hash and version in Info.plist, ad-hoc sign with rcodesign, zip.
Windows: put the new app.asar into the v1.4.0 app folder and zip it (portable).
