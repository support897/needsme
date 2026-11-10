# NeedsMe Ai native app: gap list vs the HTML spec (latest TestFlight build 324)

Done and tested in the iPhone simulator (CI run #24): sign-up first screen (Apple, Google, email), Pip tour (7 stops), Home order (Needs your attention, Continue, Projects, Recent activity), Inbox, project pages, Tasks, Notes and prompts with project suggestion, AI setup prompt, 3 themes plus Device (WCAG AA checked), Motion setting (System/Reduced/Off), Alerts settings (saved on phone only).

Not verified: Google and Apple sign-in on a real iPhone, notifications, microphone.

Still missing from the spec:
- Rooms inside projects
- Real AI connections and "AI needs you" items in the Inbox
- Home connection-health section
- Grouped recent-activity feed
- Push notifications (needs Apple setup by the owner)
- Privacy and data controls screen, "never fake integrations" audit of the AI tab
- Screenshot matrix of every theme and screen

Rules: TestFlight only, never App Review. Never create/delete certificates, profiles or keys.

## Update 9 Nov 2026 (this fold)
Done in code, not yet built: crash fix (Firebase configured from code before use), Pip tour switches tabs, every AI has an own-key or hand-off route, Privacy and data card with note export. See PLAN-2026-11-09.md.
Still missing: rooms in projects, live AI connections, Home connection health, activity feed, push, delete account, group chat room, screenshot matrix.

## Merge note 10 Nov 2026 (hand merge onto qa-fixes-2026-10-26)
The fold above now stands merged into this branch file by file. Two lines of the fold list differ from this branch shipped state and are corrected here: delete account already ships on this branch (button, alert and Store.deleteAccount, kept through the merge), and the Privacy and data card with note export landed in the merge. The crash proof is the CI UI test run on the merged head.
