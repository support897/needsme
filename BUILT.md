# BUILT — NeedsMe build 341 (builder handback)

Tree: Mac `~/nm341-build`, branch `qa-fixes-2026-10-26`, base head
**4aa14be** (build 340). All 341 work stands as **uncommitted working-tree
changes on that base — NOT pushed, NOT uploaded** (gates-before-push
steering, 14 Nov 15:17; the desk gives the ship word after Quality ·
Efficiency · QA · Reality pass on this exact tree).

Read proof (restated from the filed build note
`~/nm341-build/BUILD-NOTE-341.md` on the Mac, mirror in this folder):
round prompt md5 b52aad73 · HER-RULINGS 29b82151 · Changes spec b446ee5b ·
Bring-keys spec 8e3cb632 · route design 72289beb · build HTML
`needsmeai-chatgpt-spec-2026-11-08.html` 06e30cad (read whole, §§1–20) ·
guide 49e1541d · sprout master 75a11fef · app icon 179102d3 · QA's 340
compare read whole · kindness pack read whole.
Round skill record: `~/workspace/needsme-boss/SKILL-SEARCH-341.md`;
adoption record: `~/workspace/needsme-boss/SKILL-ADOPTION-341.md` (Scout
ruling md5 357f2405). Every step below names its skill pick; a pick is
named only where the skill's method was actually applied.

## Phase 1 — bump, door, palette

- **Build number 340 → 341** in `project.yml`, both targets; the
  xcodeproj regenerated with XcodeGen 2.44.1 (the tree's standing route —
  CI brew-installs xcodegen; the Mac had none, so the official release was
  fetched to `~/tools/xcodegen`). Pick: local-phased-delivery ·
  local-mac-bridge.
- **Item 3 — Pip on the door: BUILT.** The door now opens with Pip
  (84 pt, id `doorPip`), the "NeedsMe Ai" wordmark (`doorWordmark`) and
  the promise line from the HTML §1/§4 — "See what is moving, what is
  blocked, and what needs you." (`doorPromise`) — above the buttons.
  Button order and shape unchanged. Picks: local-design-fidelity
  (door inventory vs §4) · local-ios-accessibility (door elements are
  real buttons at full width; Pip is decorative beside the wordmark
  text) · local-explain-simply (the words are the record's own).
- **Item 4 — Google-door quiet cancel: BUILT.** `Store.googleDoor()`
  classifies errors via `Store.isDoorCancel(_:)` — the web-auth session
  cancel (domain `com.apple.AuthenticationServices.WebAuthenticationSession`
  code 1), the authorization cancel (…AuthorizationError code 1000), or a
  "cancel" in the error text. A cancel returns to the door quietly
  (`message = ""`); any other error still shows its real words. The Apple
  door is untouched. Picks: local-investigate-first (failure shape
  diagnosed from the SDK's own error contract before the fix) ·
  local-debugging-and-error-recovery (fix at the narrowest layer: the
  classifier + one call site) · local-swift-concurrency (`isDoorCancel`
  is deliberately `nonisolated static` — the auth completion arrives off
  the main actor).
- **Item 5 — true-white default: BUILT.** `Palette.white`: ground and
  cards #FFFFFF, chip #F1EEE6, line #E3DED2 (ink/soft/accent unchanged).
  `contrast.py` run fresh from the repo root on the new palette:
  **all pairs pass** (evidence: Mac
  `~/nm341-build/evidence/contrast-341.txt`). Pick:
  local-like-for-like-verification (same script, same pairs, new
  palette — the 340 cream run is the control).

## Phase 2/3 — Settings, room delete, prompt cancel, Changes, keys pull

- **Item 7 — Settings move: BUILT.** The More menu carries a profile
  header (→ Me) and ends with a Settings row (gearshape, id
  `settingsRow`). Settings holds: colours (`theme-<name>` rows), motion
  (`motionPicker`), alerts (quiet-hours toggle + `digestPicker` + the
  honest line "Push alerts are not switched on yet."), language,
  "Keys and accounts" → Connections (`settingsKeys`), "AI permissions"
  (autonomy, Draft), the Needs Me rules, privacy + data export
  (`exportNotes`), account delete (`deleteAccount`, `deleteMessage`,
  confirm alert) and sign out (`signOut`). Me holds profile only (name
  edit `nameRow`/`nameEditField`/`nameEditSave`, email/guest line,
  sign-in methods read from the account record, language, time zone) —
  no setting rows stand in Me (driven by test 14). Picks:
  local-design-fidelity (Settings contents inventoried against HTML §15
  + her Settings Law of 13 Nov, source-path comparison — see
  COMPARE-DRAFT) · local-ux-writing (row names are the actions
  themselves) · local-swiftui-expert (single NavigationStack per tab;
  views split into MoreScreens.swift).
- **Item 6 — room delete + prompt cancel: BUILT.** Rooms list carries a
  per-room delete (id `deleteRoom-<title>`) → confirm ("Delete this
  room?" / "Delete the room" / "Keep it") → `store.deleteRoom` sweeps
  the room's children, then `registryRooms(removing:)` rewrites the
  registry without it. A scheduled prompt card carries "Cancel this
  prompt" (id `cancelPrompt-<id>`, shown only while scheduled) →
  `store.cancelScheduledPrompt` writes state "cancelled" and, only on
  write success, `registryPrompts(removing:)`; cancelled prompts leave
  the waiting list. Picks: local-swift-concurrency (the delete's Task
  stays on the main actor across the sweep await; the cancel hops back
  with `Task { @MainActor in … }` from the Firestore callback before
  touching the registry — reviewed, no defects) ·
  local-ios-accessibility (the delete target is a full 44×44 button
  with the label "Delete room <title>" — fixed in the accessibility
  pass; filter chips raised to a 44 pt minimum height, Fitts's law).
- **Item 1 — Changes: BUILT.** `ChangesView` builds rows ONLY from stamps
  that already exist: tasks (filed/added/done with who + when), notes
  (added, per project), sent prompts only. Grouped by project in name
  order with **"No project yet" last**, newest first inside a group.
  Each project carries its own calm colour from an 8-colour set
  (deterministic per project name — the same project always wears the
  same colour, everywhere: Changes, Home cards, Projects, project
  detail). Percentage done comes only from the project's tasks
  (`Store.percentDone`); **the no-honest-percentage case is named: a
  project that holds notes but has no tasks has no honest basis, and
  shows "Progress not yet measurable" — no number is invented** (the
  same line stands in Projects and the project detail). Empty state is
  the spec's exact line "Nothing filed yet." Picks: local-ux-writing
  (row words front-load the action: "To-do filed:", "To-do done:",
  "Prompt sent:") · local-laws-of-ux (grouping by project = recognition
  over recall; colour is never the only signal — every dot stands beside
  the project's name and words) · local-check-ruling-source (the
  spec's "existing stamps only" rule traced to the spec file itself,
  b446ee5b, before a single row was coded).
- **Item 2 — Bring my keys in, app side: BUILT. Host side: NOT BUILT
  (the open half, named).** The app side is whole: `KeysPull` POSTs
  `https://keys.ilseplacencia.shop/keys/pull` with the signed-in user's
  Firebase ID token as a Bearer header; decodes the account list;
  places each key by provider + label — fill-only-empty (a saved key is
  never replaced; the line says so), then runs that account's own test
  in Connections; 429 answers "Too many tries just now. Give it a
  moment, then tap again."; an unreachable host answers "Could not
  reach the server. Your keys stay where they are. Try again later.";
  an empty queue answers "No keys waiting for this account." The
  "Bring my keys in" card (id `bringKeys`) stands in Connections.
  **The host half is not built: the endpoint and its relay side (the
  per-account key queue on her server) do not exist yet — VPS root SSH
  has been dead since 12 Nov ~22:52, and the desk's instruction was to
  name this half, not burn rounds on it.** Until the host stands, the
  button's honest line is what a user sees (driven by test 15). Picks:
  local-go-deep (the route design 72289beb verified against the tree's
  AIKeys write path before coding) · local-swift-concurrency (token
  fetch + POST are one async path; all Keychain writes land back on
  the main actor inside the view) · local-ux-writing (every outcome
  line says what happened and the way out; no dead ends).

## Phase 4 — kindness

- **Item 8 — Join the AI kindness revolution: BUILT, with two open
  halves named.** The menu item named exactly "Join the AI kindness
  revolution" stands **FIRST at the very top of the More menu, above
  everything else** (id `kindnessItem`; her words 14 Nov 15:19, "push
  my ai kindness brand to top" — cited in COMPARE-DRAFT as
  DIFFERENT BY HER WORD). The screen: Pip, the story, a rainbow of
  people (seven arcs in the colours of record, people standing along
  the arc, three clouds — drawn in code, static, reduced-motion safe),
  the kind-humans counter line ("Be one of the first kind humans", id
  `kindHumans`), the warm line "Your gift keeps the AI help free for
  the next person who needs a hand.", and the view-only wall (honest
  empty line "No messages yet. Yours could be the first.", id
  `kindnessWall`). A happy moment also stands in Tasks: finishing a
  task offers the wall ("Nice work, that one is done." + link id
  `kindnessMoment` + "Not now"). **Open half 1 — the giving page:** the
  "Give to keep it free" button (id `giveButton`) stands disabled with
  its note (id `giveNote`) because no live giving address is of record:
  checked live 14 Nov, `ilseplacencia.shop/kindness` → 404 and
  `kindness.ilseplacencia.shop` → 404; no URL was invented. Giving, when
  the page is live, opens in Safari — never a payment inside the app.
  **Open half 2 — "your gifts" total:** the card stands without a total
  number, because nothing in the app can measure a person's own giving
  (it happens on the Safari page); no number is printed rather than an
  invented one. Picks: local-ux-writing (money-moment tone is plain and
  serious; the warm lines are the pack's own words) · local-laws-of-ux
  (the ask appears at the moment of a finished task — the peak of the
  loop — and "Not now" is a full Button, never a shy text) ·
  local-ios-accessibility (the rainbow is decorative and hidden from
  VoiceOver — the screen's words carry the meaning; the disabled give
  button exposes its real disabled state) · local-agent-browser (the
  two giving addresses probed live before the honest shape was chosen).

## Phase 5 — the whole organisation against the HTML

**BUILT** — the reckoning list from QA's 340 compare is closed line by
line in COMPARE-DRAFT. New shape: tabs Home · Needs Me (badge = open
needs) · Projects · Notes · More; `NeedsMeScreens.swift` (Needs Me
queue grouped by project with overdue + needs-a-project sections;
Projects with per-project colour/%/needs; Your Progress) and
`MoreScreens.swift` (More menu in §2 sidebar order with kindness first,
Me, Settings, Kindness, Workforce, Sessions, Automations, Knowledge,
Operations); Home gained the §5 summary counts + "Recent wins"; Tasks
gained the AI Work Queue owner split; Connections gained the §13
catalogue (categories, method/caps/permissions/limits/last-tested,
honest work-tools card, custom-MCP registration that saves and says
"Not connected"); the Pip tour was rewritten for the new shape (7
stops). Residual NOT-DONE lines (task detail screen, note attachments,
per-agent controls, devices/workspace) stand named in COMPARE-DRAFT —
nothing is dressed as built. Picks: local-design-fidelity (element
inventory taken from the HTML sections first, then matched against
source element by element; the pictured convergence is QA's gate leg,
so the fidelity verdict here is the source-path comparison, honestly
capped) · local-swiftui-expert (writing: file-per-surface split,
NavigationStack hosted per tab, `ProgressView` name collision with
SwiftUI's own found and fixed by renaming ours `YourProgressView`) ·
local-swiftui-pro (review pass over the round's SwiftUI before this
handback: genuine findings only — the name collision (fixed), the
tappable "Not now" text (already a Button in the final tree), two
sub-44pt targets (fixed); `foregroundColor` stands as the tree's
standing style — modernization suggested, not applied during feature
work, per the skill's own rule) · local-ux-writing + local-laws-of-ux
(every new screen's words and target sizes).

## Phase 6 — item 9: connect + wake design and live proofs

Design (against HTML §§11–13 + §16, her 60-second bar): three doors,
each judged on a real live test, never on paper.
- **API key door — Pass** on standing live proofs: Gemini keys answered
  real calls on 11 Nov; build 340's Part 2 Loop filed through Gemini;
  the 12 Nov four-keys round connected each pasted key in under a
  minute with its own live test. A fresh live answer this round:
  **Could not check** — no key value is available to the builder under
  the custody law (keys live only in the relay vault and device
  Keychains), so no fresh call was faked.
- **MCP door — transport Pass, product Not proven.** A real MCP
  handshake ran on the Mac this round (minimal server + client over
  stdio JSON-RPC, kept in `~/nm341-build/item9/`): initialize answered
  (protocol 2024-11-05), `tools/list` returned `wake_agent`, the wake
  call answered — connect+list **145 ms**, wake call **1 ms**, total
  **146 ms** (evidence `item9-mcp-proof.log`). The product door is Not
  proven: no backend MCP host stands for the app, so Connections
  registers a server (name + address, saved on the phone) and labels it
  "Not connected" — never a fake connect.
- **Local bridge door — pattern proven, product Not proven.** The Part 2
  relay (member-account program on her server polling and posting while
  the app is closed) passed QA acceptance on 11 Nov — the pattern
  works. A packaged bridge a user installs on their own computer is
  designed (§16 shape) but not built.
- **The named gap:** a plain Claude chat / ChatGPT chat account (no API
  key, no Claude Code) has NO official door into a third-party app.
  Those workers are hand-off only, and the app says so (Workforce lists
  them under "Hand-off only").
- **The NEVER-SHARE fence stands verbatim in effect:** every connection,
  room and route carries exactly one owner's id; no route crosses
  owners; automatic extraction after connect is the standing Loop +
  auto-match (built 339, fall-through fixed 340).
Picks: local-go-deep (each route's verdict rests on a test that
actually ran) · local-agent-browser (giving/URL probes) ·
local-ios-debugging-instruments (the proof runs kept as logs +
timings, not impressions).

## Phase 7 — suite + drive

SUITE RESULT: **17 tests — 16 passed, 1 skipped, 0 failed**, on the
final tree, dedicated simulator NM341 (iPhone 17, iOS 27.2, UDID
285DB208-1E19-4D5E-A169-789C14FC2B0D). The one skip is test16 (Google
quiet cancel), which skips itself by design when the Google sheet's
Cancel surface does not appear in its window — DRIVE leg 19 stands
**Could not check** with that reason, never faked.
Route (named in the open): the combined `xcodebuild test` starved in
its build phase under the shared Mac's load (other desks' builds;
load averages 600–975) and was killed; the build then ran as its own
job (`xcodebuild build-for-testing` — TEST BUILD SUCCEEDED) and the
tests ran as `xcodebuild test-without-building` in nine small batches
(b1: 01+02 · b2: 03+04 · b3: 05+06 · b4: 07+08 · b5: 09+10 · b6: 11+12 ·
b7: 13+14 · b8: 15+16 · b9: 17), each with its own log + result bundle
in Mac `~/nm341-build/evidence/` (`suite-b*.log`, `suite-b*.xcresult`).
Two honest blemishes, kept in the evidence, not hidden: the first
test-without-building attempt's runner stalled in preparation and was
watchdog-killed at 383 s with zero tests executed (`suite-341b.log`);
and one batch ran with truncated `-only-testing` names that matched
zero tests and reported a hollow success with totalTestCount 0
(renamed `suite-b1-hollow.*`; the xcresult summary is what caught it —
counts are always read from the bundle, never the banner).
One test-file change was made during the drive: test03 failed twice at
the post-sign-in More step; the runner trace proved the driver's
single tab tap computed hit point {-1, -1} (tab bar present, no valid
hit point yet) and never landed — an app fault was ruled out on that
evidence. `openMore` now re-taps until the row exists (the suite's own
tapUntil discipline); **no assertion was changed and no app byte was
touched**; test03 then passed (batch b2r2, 177.8 s). Full story:
DRIVE.md leg 5.
Per-test times: 01: 104.0 s · 02: 322.6 s · 03: 177.8 s · 04: 123.4 s ·
05: 203.9 s · 06: 144.7 s · 07: 112.4 s · 08: 100.6 s · 09: 117.3 s ·
10: 98.7 s · 11: 40.1 s · 12: 89.4 s · 13: 119.8 s · 14: 98.1 s ·
15: 109.0 s · 16: skipped (55.5 s) · 17: 42.0 s.
DRIVE: the suite IS the closing test bar drive (tests 01–17: fresh
email sign-ups; door shape; image/Pip on the door; white default on a
fresh install; Changes colour + percentage; keys-pull honest line;
room delete; prompt cancel; Settings contents + Me clean; kindness
first + screen + wall; Google quiet cancel (16) and the Apple door
(17) run for real — where they stop at the accounts' own proven walls,
the leg is labelled Could not check with the wall named, never faked).
Per-leg labels stand in DRIVE.md. Picks: local-xcuitest ·
local-test-evidence-integrity (per-test result lines + attachments;
no borrowed passes) · local-ios-accessibility (the drive's screens are
the same elements the accessibility pass sized and labelled).

## Reviews run on the final tree (before this handback)

- local-code-review-and-quality, five axes over the round's diff:
  correctness (registry rewrites only after the guarded write lands;
  Changes reads only existing stamps; percent nil-paths handled),
  readability (tree patterns kept — Store extensions, Card, SoftButton;
  no system rewritten), architecture (one NavigationStack per tab;
  features in their own files), security (keys move only over HTTPS
  with the user's own ID token; no key value logged anywhere; owner id
  on every record path unchanged), performance (colour/percentage are
  computed from in-memory lists; no new listeners added).
- local-swift-concurrency: the round's async reviewed (see item 6 +
  KeysPull notes) — no defects.
- local-ios-eventkit: applied to the surfaces this round rebuilds
  (§5 Home, §8 Your Progress): the app carries dates as text and holds
  no EventKit surface; calendars-made-from-conversations stands as the
  idea of record with no calendar wiring in this round — named, not
  built, not claimed as used beyond this review.
- local-ios-push-notifications: applied to the NEEDS-YOU alert surface:
  the in-app badge + Needs Me tab + Settings choices (quiet hours,
  digest) stand; no APNs registration or authorization request ships in
  this round (no push item in the pack), and the Settings line says
  exactly that — reviewed against the skill's contracts, no push code
  claimed.
- local-ci-cd-and-automation + local-shipping-and-launch: applied to
  the ship-leg shape in the final report (tarball repack rule, workflow
  triggers, unsorted ASC read, group-side verification). The leg itself
  is gated by the desk and was NOT run.
- store-review: the submission gate belongs to the ship; the facts it
  will check are recorded here (exactly three doors — Google, Apple,
  email; account delete inside Settings; privacy words inside the app;
  no in-app payment anywhere, giving leaves to Safari). The full sweep
  is the Store Review desk's on the assembled package — not run here
  and not claimed.
- NOT used this round, never claimed: local-ios-widgetkit (no widget
  item in the pack), local-ios-swiftdata, local-ios-cloudkit (the data
  layer of record is Firestore). Bench only: local_shared_auth_session_sweep
  (runs on a sign-in landing, per Loadout).

## Two cause lines the record owed (Supervisor rounds 50–51)

- **KINDNESS — the failed site fetch, and the route that replaced it.**
  Early in the round, the text fetch of `kindness.ilseplacencia.shop`
  failed: the address answers **404** — no live kindness site stands
  there (checked live 14 Nov via browser.open; `ilseplacencia.shop/kindness`
  also answers 404). The route that replaced it: **the local design of
  record, `JOIN-AI-KINDNESS-DONATION-PACK.md`** (the kindness pack in
  `~/workspace/goals/become-the-next-woman-in-business-creator/files/`,
  read whole before item 8 was coded). The item-8 build stands on that
  pack — the menu name, the story, the rainbow of people, the clouds,
  the view-only wall, and the give-in-Safari shape all come from it. No
  live page was ever the design source, and no giving URL was invented
  from the failed fetch (see item 8's open halves above).
- **TASKSVIEW — the failed edit, its cause, and the proof the final
  tree carries the change.** Mid-round, an edit to `TasksView.swift`
  failed with "text not found". **Cause: stale old_text** — the local
  working copy had drifted from the sources that actually stood (and
  compiled) on the Mac, so the text the edit reached for was not in the
  file. Cure, applied the same hour: the file was **re-read from the
  Mac tree itself**, and the intended change was verified standing in
  it — the Tasks kindness moment's "Not now" is a real `Button`
  (`showKindness` state), exactly as designed; nothing needed
  re-applying in TasksView. The only genuinely missing fixes were in
  RoomView (the 44 pt delete target, the 44 pt filter chips), and those
  were reapplied against the re-read text and compiled. **Proof the
  final tree carries the intended TasksView change:** the tree diff
  (CHANGED-PATHS.txt, TasksView among the changed paths), the two
  BUILD SUCCEEDED runs on the final tree, and the suite legs that drive
  Tasks on those bytes — test02 FullJourney, green in batch b1,
  exercises the Tasks screen and its kindness moment.

## Fix round — the four returned surfaces (Quality's return list, 14 Nov)

Quality's verdict on the main round was NOT PASS, on the close only: four
HTML surfaces still stood in NOT DONE YET (§9 task detail, §10 note
attachments, §11 per-agent controls, §15 devices / workspace). The fix
round built all four in code at the Boss desk, staged them, and — after
the Mac outage (14 Nov ~18:16–22:17) — this resume run landed them on
the main round's tree, drove the full suite (tests 01–21) on the final
tree, and files this section from that run only. Skill picks for the
resume run, named in the build note's first line and beside each step
below: local-mac-bridge · local-swiftui-pro + local-swift-concurrency ·
local-surgical-patch · local_test_evidence_integrity ·
local_check_ruling_source · local-small-steps · local-ralph ·
local-go-deep.

- **Landing (pick: local-surgical-patch · local-mac-bridge).** The six
  staged files (Store, TasksView, RoomView, NotesView, MoreScreens,
  NeedsMeUITests) were backed up from the tree first
  (`~/nm341-build/pre-fix-round-backup/`, the pre-fix md5s stand in the
  resume record), then landed with pairwise md5 proof — staging md5 ==
  Mac md5 for every file, at landing and after every in-run fix below.
  Final landed md5s: Store `5b7d0f35` · TasksView `66eb85f2` · RoomView
  `2ee57a6f` · NotesView `5ab81aed` · MoreScreens `056c782f` · tests
  `43d69377` (8-char prefixes; the full values stand in the resume
  handback report).
- **§9 task detail — BUILT (picks: local-swiftui-pro ·
  local-surgical-patch).** Tapping a task row opens `TaskDetailView`:
  fields (project, status — including "Blocked by …" from open
  dependencies, owner, due), a checklist that rides on the task
  document (add / toggle / remove), dependencies (add / remove against
  the task's own list), a session timeline, an evidence card, and an
  Actions card (Mark done / Mark not done, Delete this task). Fields
  with no record behind them say so in plain words — no priority and
  no outcome are recorded for any task, and both lines say exactly
  that (§19). Suite leg: test18 (see its fix story below).
- **§10 note attachments — BUILT, on the finding named here in the open
  (picks: local-check-ruling-source · local-swiftui-pro).** THE
  FINDING: there is NO rooms image path of record — no PhotosPicker,
  no Firebase Storage, no image code anywhere in the tree or its git
  history; the COMPARE-DRAFT line claiming image upload "stands in
  rooms (shipped 339)" was WRONG and is STRUCK (the correction stands
  in COMPARE-DRAFT, dated to this round). Attachments are therefore
  the app's first and only image path: a note's pictures are picked
  with PhotosPicker, shrunk to JPEG, and kept as documents UNDER THE
  OWNER'S OWN NOTE (`notes/{id}/attachments`), standing inside the
  note, removable one by one, swept on account delete; a too-large
  picture answers its honest line. Suite leg: test19 — it skipped
  itself (the system picker's surface never appeared in the
  simulator drive), so the pictured leg stands Could not check with
  that cause, named for QA's gate drive; the code stands in the tree.
- **§11 per-agent controls — BUILT (picks: local-swiftui-pro ·
  local-swift-concurrency).** The Workforce screen carries, per
  connected AI: Pause / Resume, Cancel run, a project pick, and three
  tool switches (Answer in rooms · Read talks and notes · File
  to-dos). The controls truly act: they persist per owner in
  `settings/agents` and are read by the room answers, the talk
  reading, the Loop's filing, the DONE crossings and auto-match; a
  cancel drops an in-flight reply and notes it in the room. FENCE
  CALL (Quality, accepted 14 Nov): **no per-agent autonomy picker
  ships** — the app's levels would not truly act differently per
  agent, so a picker would be a dead control dressed as working
  (§19); the absence is named in COMPARE-DRAFT under DIFFERENT,
  headed "Different by §19 honesty", never as a silent gap. Suite
  leg: test20 (see its fix story below).
- **§15 devices + workspace — BUILT (picks: local-swiftui-pro ·
  local-check-ruling-source).** THE DEVICES HALF, in its own words:
  this device registers itself at sign-in in her settings space as
  `settings/device-<id>` — first seen is set once, last seen is
  refreshed on each sign-in — and Settings ▸ Devices lists it marked
  **"This device"**, with its name, model and system version. That is
  exactly what the landed code does, no more. THE WORKSPACE HALF:
  FENCE CALL (Quality, accepted 14 Nov) — the workspace is built
  **owner-only**: it shows "You · Owner" and states that AIs, keys
  and data are never shared; there are no invitations and no other
  seats, because §16's owner isolation is the app's standing shape.
  Suite leg: test21 — Pass on its first run (56.4 s).

### In-run fixes (every one named; staging and tree kept md5-equal)

1. **Compile error in the fix round's own Store.swift** — the first
   build-for-testing failed (exit 65): `Store.swift:151` set
   `attHandles = []` where the property is a `[String:
   ListenerRegistration]` dictionary. Fixed to `[:]`; the rebuild
   stands TEST BUILD SUCCEEDED (`fix-build2.log`). Pick:
   local-debugging-and-error-recovery.
2. **Detail toggle label** — batch b1's first run failed test02 at
   "Mark not done": the new detail's toggle read "Reopen", a word
   that stood in exactly one place in the app, against the app's
   standing label pair ("Mark done" / "Mark not done", the queue
   row's labels, which tests 02 + 12 wait on). Fixed at
   TasksView.swift's detail toggle. Pick: local-surgical-patch.
3. **Test-helper email draw** — b1's second run failed test02's
   sign-up with "The email address is already in use" (the app's
   correct answer): `signUpFresh()` and test03 drew account tags
   from a 9,000-address space the accumulated suite accounts had
   exhausted. Both draws widened to a 900-million space. Harness
   only — **no assertion changed, no app byte touched by this fix.**
   Pick: local_test_evidence_integrity.
4. **Kindness moment on the detail (first shape)** — b1 kept failing
   test02's kindness wait: finishing a task from the detail offered
   no moment (the offer lived only in the queue's view state).
   The moment was mirrored into the detail's Actions card. Pick:
   local-swiftui-pro.
5. **Kindness offer moved into the Store (the shape that stands)** —
   the detail mirror alone did not close it: the queue row's tap was
   firing BOTH its toggle and its new detail link, so the finished
   state stood on the pushed detail while the moment stood on the
   covered queue. The offer now lives in the Store
   (`Store.kindnessOffer`, raised inside `toggle` — the single choke
   point for marking done) and BOTH task surfaces read it; the two
   views' local state was removed. test02 then passed (644.2 s).
   Picks: local-investigate-first · local-swiftui-pro.
6. **Queue row double-fire stopped** — test18 then failed on the
   same row from the other side: opening a task's detail had ALSO
   marked the task done (status read "Completed" where the test
   asserts "Blocked by Blocker task"). The row's toggle Button now
   carries `.buttonStyle(.borderless)`, so the checkbox claims only
   its own frame: tap the box, the task toggles; tap the row, the
   detail opens — never both. test18 passed on the re-run
   (246.8 s), and test02 + test12 were re-proven on the final bytes
   (fix-recheck: 292.5 s · 102.8 s). Pick: local-surgical-patch.
7. **§11 tool switches made true switches** — test20 failed twice
   (batch + solo) at "file tool switch did not turn off": the
   labelled SwiftUI Toggle's element spans label + knob, so the
   drive's centre tap landed on the label and never actuated the
   switch (the Store plumbing was read and is correct: `agentMay` /
   `setAgentControl` round-trip, proven by the pause half of the
   same test passing). The row is now a plain Text label beside a
   label-hidden Toggle, so the switch element IS the knob. test20
   passed on the re-run (246.7 s), persistence half included. Pick:
   local-ios-accessibility (the control's element is the control).

### Fix-round suite (counts read only from the xcresult bundles)

**21 tests — 19 passed · 2 skipped · 0 failed**, on the final tree
(build-for-testing stands TEST BUILD SUCCEEDED on the exact shipped
sources; batches `fix-b1`…`fix-b11` plus the named re-runs `fix-b6r`,
`fix-b9r`, `fix-b10r2`, `fix-recheck`, `fix-recheck14`, all in
`~/nm341-build/evidence/`). The two skips are the tests' own guards:
test16 (leg 19, Google quiet cancel — the sheet's Cancel surface
never appeared; Could not check, QA's door lane carries it) and
test19 (the §10 picker surface, above). Kept failure evidence, not
hidden: b1's hollow zero-test attempt (two-part `-only-testing`
names), its preparation stall (watchdog-killed, re-run), test01's
`kAXErrorServerNotFound` accessibility drop in one attempt, test11's
batch swipe failure under load (passed solo in 33.4 s on the same
bytes), test02's three failed attempts, test18's first-run failure,
test20's two failures — each bundle preserved under its r-name.
Per-test times and legs: DRIVE.md, fix-round legs. Picks:
local-xcuitest · local_test_evidence_integrity.

## Ship warning for the desk's ship step (not run by me)

CI consumes `ios-native.tar.gz` at the repo root — **the tarball must be
repacked from the final `ios-native/` before any push, or CI builds the
old 340 sources.** This tree carries source changes only; the tarball is
untouched. `testflight.yml` is workflow_dispatch and sets the build
number from the run number + 100; the local tree is stamped 341 in
project.yml. Verify the shipped build on the UNSORTED ASC builds list
and from the two internal groups' own build lists (Review Recordings +
Device Route QA).

## QA loop round (15 Nov, this desk at the Boss's hand) — legs 19 + 22 test fixes

Skill picks: local-xcuitest · local-test-evidence-integrity ·
local-like-for-like-verification (QA's named list, both items test-file
only; no app byte implicated in either, and no app byte changed).

QA's one named loop list arrived 03:14 with its own photographs as
proof. Both fixes landed in `NeedsMeUITests.swift` only:

- Leg 19 (test16): the wait for `buttons["Cancel"]` could never match —
  this runtime's web-auth sheet exposes an ✕ close glyph, not a Cancel
  button (QA shot `27-google-no-page-qa.png`; the test skipped at the
  builder's hand and at QA's, 79.664 s). The test now polls 25 s for the
  sheet's close control by glyph or label (✕ / × / Close / Cancel,
  direct buttons then a label predicate) via a new `sheetCloseControl()`
  helper, taps it, and the settled-door assertions after it stand
  exactly as written. If no close control appears, the leg still skips
  with the same honest reason.
- Leg 22 (test19): the late system "Save Password?" sheet from the
  test's own sign-in stood over the seeded picker (QA shot
  `31-picker-seeded-qa.png`), so the cell poll found nothing tappable
  and skipped (147.9 s). The test now registers an interruption monitor
  for the sheet, dismisses it explicitly right before the picker poll,
  and dismisses it inside the poll loop via a new
  `dismissSavePasswordSheet()` helper (taps "Not Now" in buttons,
  sheets or alerts scope). The §10 attach flow itself was not faulted
  by QA's evidence and is untouched.

Prints: test file 43d69377cf74fbb79a9de5e7ade9bdc9 →
d0a6f631d48e75b8baf3bfdb7cd4d6fb, identical on the Mac tree and in
`~/workspace/needsme-341-build/fix-round-staging/`; the pre-fix file
stands backed up at `~/nm341-build/evidence/NeedsMeUITests.swift.pre-qa-loop-2026-11-15`.
Diff against that backup touches only the two tests plus the two new
helpers (verified on the Mac). HEAD still 4aa14be, tree porcelain still
26 entries — the tree's state is otherwise exactly the fix-round finish.

Compile proof: `xcodebuild build-for-testing` on the NM341 sim against
`~/nm341-build/DerivedData` closed with ** TEST BUILD SUCCEEDED **, so
the refreshed test bundle in DerivedData carries the new test code for
QA's test-without-building re-runs of test16 + test19. Those re-runs
are QA's; their verdicts close legs 19 and 22 in QA's verdict file.

## QA loop round 2 (15 Nov, this desk) — legs 19 + 22, second fixes

Skill picks: local-xcuitest · local-test-evidence-integrity ·
local-like-for-like-verification. Test file only again; no app byte
implicated or changed in either leg.

QA's round-1 re-runs moved the proof one step deeper on both legs:

- Leg 19 (test16) FAILED (76.5 s, `qa-test16b.xcresult`): the round-1
  helper found and tapped a "Close" button (38.21 s) and the
  Safari-shaped container still stood at the assert, its chrome still
  showing Stop — the page was still loading, so the tap was swallowed,
  or that Close was not the container's own dismiss element. Round-2
  shape: a `sheetCloseCandidates()` helper (every close-shaped button,
  glyph first, up to two per label); the test settles first (waits for
  the chrome's Stop button to clear, up to 10 s), then taps and watches
  for the door, re-tapping and cycling the candidates until the door
  returns or 30 s pass. The settled-door assertions stand as written.
- Leg 22 (test19) SKIPPED again (96.5 s, `qa-test19c.xcresult`), sheet
  half CURED — zero "Save Password" in the log and QA's shot
  `32-picker-fixed-qa.png` shows the picker fully loaded, six photos
  standing, no sheet over it. The remaining cause was the poll query:
  this runtime's out-of-process picker never surfaces its grid items
  under the app hierarchy's cells/images. Round-2 shape: the poll now
  searches the picker's own process scopes
  (`com.apple.Photos.PhotosPicker`, `com.apple.photos.picker`) as well
  as the app's, across cells, images and grid buttons (picker chrome
  labels skipped), and the Add/Done confirm searches the same scopes.

Owned compile fault, named plainly: the first round-2 print
(b76382ca) FAILED its compile — `app.buttons[name]` returns an element,
not a query, so `.count`/`.element(boundBy:)` did not typecheck in
`sheetCloseCandidates()` (log `~/nm341-build/evidence/loop2-build.log`,
XCEXIT 65, two errors, both that function). Fixed with
`app.buttons.matching(identifier:)` and rebuilt.

Final prints: test file d0a6f631d48e75b8baf3bfdb7cd4d6fb →
1312adc91a69b5b29665c5303781ecbd, identical on the Mac tree and in the
staging mirror; the round-1 file stands backed up at
`~/nm341-build/evidence/NeedsMeUITests.swift.pre-qa-loop2-2026-11-15`.
HEAD still 4aa14be, porcelain still 26 entries. Compile proof:
build-for-testing on the NM341 sim closed ** TEST BUILD SUCCEEDED **
(XCEXIT 0, zero error lines; log
`~/nm341-build/evidence/loop2-build2.log`), DerivedData refreshed.
QA re-runs test16 + test19 on this bundle; their verdicts close legs
19 and 22.

## QA loop round 3 (15 Nov, this desk) — legs 19 + 22, third fixes

Skill picks: local-xcuitest · local-test-evidence-integrity ·
local-like-for-like-verification. Test file only again; no app byte
implicated or changed; no assertion changed.

Round-2 re-runs at QA's hand: BOTH legs FAILED with assertions running
(the skips are gone) — each failure named its mechanism precisely.

- Leg 19 (test16) FAILED (95.8 s, `qa-test16c.xcresult`): the failure
  dump shows the container FULLY LOADED (firebaseapp.com sign-in page:
  Close, Address, Page Menu, Back, Share, Reload, "Forgot email?",
  Next) and the settle + re-tap cycle ran its full 30 s against that
  standing page — the element tap on the remote container's Close
  exists but does not take effect. MECHANISM for round 3 (named, as QA
  required): a frame-coordinate tap — each round the test tries the
  element tap once, then taps the candidate's frame centre as a
  coordinate on the app window, the frame read from the element itself
  (hierarchy data), never from a photograph; candidates cycle; the
  door is watched between attempts; window widened to 35 s.
- Leg 22 (test19) FAILED (72.2 s, `qa-test19d.xcresult`) at the poll:
  querying the PhotosPicker process before it is running THROWS
  ("Failed to get matching snapshots: Application
  com.apple.Photos.PhotosPicker is not running") and fails the whole
  test. Round-3 shape: a scope is only ever queried while its process
  state reads running (foreground or background) — the poll survives
  the picker's lazy start — and the SpringBoard scope stands in the
  scope list as the always-running fallback surface. The Add/Done
  confirm carries the same guard.

Final prints: test file 1312adc91a69b5b29665c5303781ecbd →
0b0084c52f03031677c433546bc8ba5f, identical on the Mac tree and in the
staging mirror; the round-2 file stands backed up at
`~/nm341-build/evidence/NeedsMeUITests.swift.pre-qa-loop3-2026-11-15`.
HEAD still 4aa14be, porcelain still 26 entries. Compile proof:
build-for-testing on the NM341 sim closed ** TEST BUILD SUCCEEDED **
(XCEXIT 0, zero error lines; log
`~/nm341-build/evidence/loop3-build.log`), DerivedData refreshed.
QA re-runs test16 + test19 on this bundle.

## QA loop round 4 (15 Nov, this desk) — leg 19 CLOSED, leg 22 fourth fix

Skill picks: local-xcuitest · local-test-evidence-integrity ·
local-like-for-like-verification. Test file only; no app byte changed;
the note assert stands as written.

**LEG 19 CLOSED — PASS.** QA's round-3 re-run of test16 PASSED whole
(60.279 s, `qa-test16d.xcresult`): the frame-centre coordinate tap
dismissed the Google container and the settled door stood quiet. The
Google quiet cancel is proven on the final tree.

Leg 22 (test19) round 3 FAILED (135.6 s, `qa-test19e.xcresult`) deeper
in: the poll tapped an Image labelled "wifi" — chrome outside the
grid, matched through a fallback scope — and no Add/Done confirm ever
fired, so nothing reached the app. §10's save path unproven; no app
fault named.

Round-4 shape, both halves of QA's named call:

- The pick is BOUND TO THE GRID. A candidate counts only if its own
  frame reads as a photo tile inside the grid: square-ish (within a
  quarter of its width), at least 60 pt a side, centre inside the
  window, and standing below the picker's own chrome — the Photos /
  Collections tabs mark the grid's top edge when they stand (default
  100 pt). Cells are read first, then images; buttons are no longer
  pick candidates at all.
- The confirm is a HARD step, asserted. After the pick, the test polls
  up to 15 s and must land an Add/Done tap, or see the picker return on
  the pick itself (the app's attachPhoto standing hittable again);
  anything else fails at the confirm with its own assert, not later at
  the note.

Final prints: test file 0b0084c52f03031677c433546bc8ba5f →
7c4527d9b5423a593a99e8aefb7b952a, identical on the Mac tree and in the
staging mirror; the round-3 file stands backed up at
`~/nm341-build/evidence/NeedsMeUITests.swift.pre-qa-loop4-2026-11-15`.
HEAD still 4aa14be, porcelain still 26 entries. Compile proof:
build-for-testing on the NM341 sim closed ** TEST BUILD SUCCEEDED **
(XCEXIT 0, zero error lines; log
`~/nm341-build/evidence/loop4-build.log`), DerivedData refreshed.
QA re-runs test19 alone on this bundle.
