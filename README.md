# NeedsMe for Mac

All your AIs in one calm place. Sign in once with Apple, Google or email. Connect each AI once. Tap to switch.

Run:  `npm install` then `npm start`
Make a double-click app:  `npm run build`  (app appears in `dist/mac-arm64/NeedsMe.app`)

## Files
- `main.js`  window, saved AI logins (one cookie jar per account), page reading, notifications, Needs Me sign-in
- `index.html`, `style.css`, `icons.js`, `app1-4.js`  the whole screen (matches NeedsMe design v3)
- `catalog.json`  the AI list. Add one line to add a new AI.
- `test/`  browser test page with sample data

## Honest limits
- Chats, Needs Me and scheduled prompts work by typing into / reading each AI's real web page. If a site changes, they may need a small fix.
- Terminal AIs (OpenCode, Claude Code CLI, Codex CLI, Gemini CLI) are listed but not wired yet.
- Scheduled prompts send only while the Mac is on and NeedsMe is open (they send on wake if late).
- Mac App Store submission needs Apple signing and sandbox work. Not done.
