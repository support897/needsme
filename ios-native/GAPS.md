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
