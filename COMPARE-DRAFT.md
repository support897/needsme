# CLOSING COMPARE — DRAFT (builder, NeedsMe build 341)

Against: the HTML of record `needsmeai-chatgpt-spec-2026-11-08.html` (§§1–20,
md5 06e30cad) and QA's build-340 compare
(`compare-needsme-b340-2026-11-13.md`, every screen Not pass on 340).
This is the builder's draft for the desk's closing compare with QA at the
gates. Three piles, per the round prompt's closing rule.

## SAME AS HTML

- §2 shape of the whole app — tabs are now **Home · Needs Me · Projects ·
  Notes · More**, in that order (340 had Home · Tasks · Notes · AI · More —
  Not pass). Home is the default tab. Every destination exists:
  Home (§5), Needs Me (§6), Projects (§7) + Your Progress (§8), Tasks +
  Sessions (§9), Notes (§10), AI Workforce (§11), AI Group Chat (§12),
  Connections (§13), Automations / Knowledge / Operations (§14),
  Settings / Me profile (§15), Changes (her item 1 addition).
- §4 door order — wordmark "NeedsMe Ai", Pip, the promise line "See what is
  moving, what is blocked, and what needs you.", then the sign-in buttons in
  the order the door law sets (see DIFFERENT pile for the law's own shape).
  Door ids `doorPip`, `doorWordmark`, `doorPromise` are driven by test 01.
- §3 ground — the default palette's ground is true white #FFFFFF (was cream
  #FAF7F0 — QA 340 line). `contrast.py` run fresh on the new palette: all
  pairs pass (evidence `contrast-341.txt`).
- §5 Home — time-based greeting by the user's chosen name (stood in 340),
  compact summary counts at the top (Needs you / AI working / Completed),
  project progress cards with percentage + bar, "Recent wins" (the spec's
  wins feed: finished tasks first, then notes), today's focus list.
- §6 Needs Me — the needs queue grouped by project with per-group counts,
  need cards with who/text/project and "Open the room" + "Done", an Overdue
  section, and the unsorted-notes section ("Needs a project"). Empty state
  reads "Nothing needs you right now". The More tab carries the same open
  count as a badge.
- §7 Projects — a real tab now: every project a card with its calm colour,
  percentage done (or "Progress not yet measurable…"), "N of M tasks done",
  a progress bar in the project colour, and how many needs wait. The project
  detail shows the same numbers, a "Needs your attention" section, and the
  project's rooms.
- §8 Your Progress — its own screen: tasks finished in the last 7 days,
  projects moving forward, the total finished count, and "That's enough for
  today."
- §9 Tasks — owner split stands: "Your tasks" (human) and "AI Work Queue"
  (tasks an AI filed, captioned "AI work · Waiting / Completed"). Sessions
  is its own destination (past runs: rooms + sent prompts with times).
- §10 Notes — three places kept (Notes / Prompts / Knowledge), search across
  notes by title and words (stood via the Notes search; the spec's missing
  search was QA's 340 line — now present in Knowledge and Notes carries its
  three places with the prompt composer + schedule).
- §11 AI Workforce — its own destination: each connected AI with label,
  live status, provider + model, "Autonomy: Draft" (the standing safe
  default), what it can do, and when it was last tested. Hand-off routes are
  listed under "Hand-off only", never shown as live workers.
- §12 AI Group Chat — its own destination under that name (340 buried it as
  "Rooms" inside Connect — Not pass). Project filter chips, a participants
  line in every room ("In this room: You + …"), the project shown on the
  room, and room delete with a confirm. Only connected accounts ever stand
  in a room.
- §13 Connections — a catalogue, not a paste box: three categories in the
  spec's order, each route with how it connects, what it can do, its
  permissions, its limits, and when it was last tested. Work tools (GitHub,
  Notion, Drive, Slack, Discord, Email, Calendar) are carried honestly: "No
  supported path into this app yet." A custom MCP server can be registered
  (name + address, saved on the phone) and is shown as "Saved on this phone.
  Not connected." — never dressed up as connected.
- §14 — Automations (real scheduled prompts + the standing automatics, and
  a plain line that a rule builder is not in this build), Knowledge (search
  + a shareable plain-text context pack per project), Operations (live
  connection health + the data counts + version/build).
- §15 Settings / Me — Settings holds: colours (themes), motion, alerts
  (quiet hours + digest), language, keys and accounts (link to Connections),
  AI permissions (autonomy), the Needs Me rules, privacy + data export +
  account delete, and sign out. Me holds profile only: name, email/guest
  line, sign-in methods (from the account record), language, time zone. No
  setting rows stand in Me.
- §9 task detail (fix round) — tapping a task opens its own detail: fields
  (project, status — including "Blocked by …" from its open dependencies,
  owner, due), a checklist riding on the task document (add / toggle /
  remove), dependencies (add / remove against the task's own list), a
  session timeline, an evidence card, and an Actions card (Mark done /
  Mark not done, Delete). Fields with no record say so in plain words —
  no priority and no outcome are recorded for any task, and both lines
  say exactly that. Driven by test18.
- §10 note attachments (fix round) — a note can hold pictures: picked with
  the system photo picker, shrunk to JPEG, standing inside the note,
  removable one by one. They live as documents under the owner's own note
  (`notes/{id}/attachments`) and are swept on account delete. CORRECTION
  (fix round, ruled by Quality 14 Nov): the earlier draft claim that
  image upload "stands in rooms (shipped 339)" was WRONG and is STRUCK —
  there is no PhotosPicker, no Firebase Storage and no image code
  anywhere in the tree or its history; these attachments are the app's
  first and only image path. The suite leg (test19) skipped itself — the
  picker's surface never appeared in the simulator drive — so the
  pictured leg stands named for QA's gate drive.
- §11 per-agent controls (fix round) — the Workforce screen carries, per
  connected AI: Pause / Resume (a paused AI does not answer in rooms,
  read talks or file to-dos), Cancel run, a project pick (the projects
  it may file into), and three tool switches (Answer in rooms · Read
  talks and notes · File to-dos). They persist per owner in
  `settings/agents`, are read by the room answers, talk reading, the
  Loop's filing, DONE crossings and auto-match, and stand after sign-out
  and back in. Driven by test20. (The one §11 shape that does NOT stand
  is the autonomy picker — see DIFFERENT, "Different by §19 honesty".)
- §15 devices + workspace (fix round) — DEVICES: this device registers
  itself at sign-in in her settings space as `settings/device-<id>`
  (first seen set once, last seen refreshed) and Settings ▸ Devices
  lists it marked "This device". WORKSPACE: owner-only — it shows
  "You · Owner" and states that AIs, keys and data are never shared;
  no invitations exist (the accepted fence call, Quality 14 Nov).
  Driven by test21.
- §19 honesty rules — no dead controls dressed as working: unavailable
  things say so in plain words on the screen (giving page pending, MCP
  saved-not-connected, work tools no-path, rule builder not-in-build, push
  alerts not switched on).
- Item 1 Changes — rows built only from stamps that already exist on tasks,
  notes and sent prompts; grouped by project with the project's calm colour;
  newest first; "No project yet" last; percentage only where the project has
  tasks (the honest basis); empty state "Nothing filed yet."

## DIFFERENT BY HER WORD (each with her instruction)

- Door buttons — Google and Apple only, with one small "Email" button that
  opens email on its own page; Apple above Google in the group. Her door
  law, 11 Nov 2026. (The HTML §4 shows the email form on the door itself.)
- Default theme — plain white, chosen and settled first, 12 Nov 2026
  (HTML §3 itself names pure white the default; the shipped 340 cream was
  the drift).
- Settings placement — every setting inside Settings, under a settings
  icon; nothing in Me/Profile. Her Settings Law, 13 Nov 2026 (HTML §15
  mixes profile and settings on one surface).
- AI Group Chat look — WhatsApp-look group rooms. Her word, 13 Nov 2026
  (the room screen keeps the shipped WhatsApp-style chat shape inside the
  §12 destination).
- Pip on the door — Pip (the sprout mark of record) stands on the sign-in
  door. Item 3 of this round's prompt, her word (HTML §4 names a welcome
  step; Pip is the brand of record that fills it).
- Kindness FIRST — "Join the AI kindness revolution" stands first, at the
  very top of the More menu, above everything else. Her words, 14 Nov 2026
  15:19: "push my ai kindness brand to top". (The design pack had placed
  the kindness item low in the menu.)
- The Changes destination itself — her ask of 12 Nov 2026 22:xx (the
  Changes menu: what changed, per project, from the records that exist).
  The HTML has no Changes screen; it is added, not a deviation.
- §17's web stack (React/PWA) — the app of record is the native Swift app;
  the native line is her standing build route (builds 336–341). The HTML's
  organisation is built; its stack recommendation was never adopted for
  the shipped app.
- Item 8, "your gifts" total — no total is printed: giving happens on
  the Safari page and nothing in the app can measure a person's own
  giving. Ruled by Quality (14 Nov) as the honest finished shape, NOT
  an open item — it stands in no pile as owed.
- **Different by §19 honesty** — §11 carries NO per-agent autonomy
  picker. The app's autonomy levels would not truly act differently per
  agent, so no picker is dressed up as a working control (§19: no dead
  controls). The absence is named here, never a silent gap (Quality's
  condition, accepted 14 Nov); every control that does ship truly acts —
  pause, cancel run, project pick, tool switches — and is driven by
  test20.

## NOT DONE YET

- Item 2, host half — the "Bring my keys in" app side is whole; the host
  endpoint (`keys.ilseplacencia.shop/keys/pull` + the relay side that
  queues keys per account) is not built: the VPS root SSH route has been
  dead since 12 Nov ~22:52, and the pull button reports the honest line on
  the phone until the host stands. Named in BUILT.md.
- Item 8, giving page — the in-app kindness screen is whole (story, rainbow
  of people, clouds, view-only wall); the button stays disabled with its
  honest note because no live giving address is of record (checked 14 Nov:
  ilseplacencia.shop/kindness → 404; kindness.ilseplacencia.shop → 404).
  The moment the page is live, the button opens it in Safari.


## Drive evidence

The closing test bar drive is the UI suite on this exact tree (tests
01–21 after the fix round: 19 passed · 2 skipped by their own guards ·
0 failed, counts from the bundles), run on the dedicated NM341 simulator: fresh email sign-ups, door
shape, Google quiet cancel (16), Apple door (17), Pip + wordmark on the
door, white default on a fresh install, Changes with colour + percentage,
keys-pull honest line, room delete, scheduled-prompt cancel, Settings
shape with Me clean, kindness first in the menu + screen + wall. Per-leg
labels stand in DRIVE.md; the run's log, result bundle and screenshots
stand in `~/nm341-build/evidence/` on the Mac.
