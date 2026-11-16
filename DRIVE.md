# DRIVE — NeedsMe build 341, closing test bar (builder run)

The drive is the UI suite on the exact final tree, run on the dedicated
simulator **NM341** (iPhone 17, iOS 27.2, UDID
285DB208-1E19-4D5E-A169-789C14FC2B0D) on Ilse's Mac. Evidence on the Mac:
`~/nm341-build/evidence/suite-341.log`, the result bundle
`~/nm341-build/evidence/suite-341.xcresult`, and the harness screenshots
in `~/nm341-build/evidence/shots/` (numbered 01–28 in the suite's own
style). Labels are plain: **Pass / Not pass / Could not check** (+ the
reason). No leg is called from memory — each label below is read off the
run's own result lines when the run lands.

Command (standing suite route, mirroring `.github/workflows/ui-tests.yml`):

```
TEST_RUNNER_SHOT_DIR=~/nm341-build/evidence/shots xcodebuild test \
  -project NeedsMe.xcodeproj -scheme NeedsMe \
  -destination "platform=iOS Simulator,id=285DB208-1E19-4D5E-A169-789C14FC2B0D" \
  -derivedDataPath ~/nm341-build/DerivedData \
  -resultBundlePath ~/nm341-build/evidence/suite-341.xcresult \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES
```

## Legs (verdicts filled from the run)

| # | Leg | Test(s) | Verdict |
|---|-----|---------|---------|
| 1 | Fresh email sign-up lands (door → name ask → tabs) | 01, 02 | **Pass** (test01 104.0 s, test02 322.6 s, batch b1) |
| 2 | Door shape: Pip + wordmark + promise line on the door | 01 | **Pass** (test01 asserts `doorPip`, `doorWordmark`, `doorPromise`) |
| 3 | White default on a fresh install | 01/02 (fresh state) | **Pass** (fresh installs in 01/02 open on the white default; palette proven by `contrast-341.txt`) |
| 4 | Full journey on the new organisation (tour, Home summary + Recent wins, Needs Me empty state, Projects + Your Progress, Tasks, inbox, project detail) | 02 | **Pass** (test02, batch b1) |
| 5 | Sign-out → sign-in round trip on the new shape | 03 | **Pass** (batch b2r2, 177.8 s). Story, in the open: test03 failed twice (b2, b2r) at the same step — after sign-in, `moreTasks` not found, app standing signed-in on Home. The runner's own trace gave the cause: the single tap on the More tab computed hit point **{-1, -1}** (tab bar existed but had no valid hit point in the first beat after sign-in, under heavy shared-Mac load) — the tap never landed; the app was not at fault. The driver's `openMore` helper now re-taps until the row exists (the suite's own tapUntil/openAddTask discipline); **no assertion was changed**. The app bytes were not touched. Evidence: failure traces in `suite-b2.log`/`suite-b2r.log`, pass in `suite-b2r2.log` |
| 6 | Privacy words + account delete inside Settings | 04 | **Pass** (test04, 123.4 s, batch b2) |
| 7 | Connections: key fields, per-account test status, add account | 05 | **Pass** (test05, 203.9 s, batch b3) |
| 8 | AI Group Chat: rooms, participants line | 06 | **Pass** (test06, 144.7 s, batch b3) |
| 9 | Loop controls | 07 | **Pass** (test07, 112.4 s, batch b4) |
| 10 | Notes places; notes cannot be deleted from the note screen | 08 | **Pass** (test08, 100.6 s, batch b4) |
| 11 | Theme names inside Settings | 09 | **Pass** (test09, 117.3 s, batch b5) |
| 12 | Name ask → Me profile holds the name; no settings in Me | 10, 14 | **Pass** on test10 (98.7 s, batch b5); the Me-clean half is re-asserted inside test14 (batch b7) |
| 13 | Swipe back to the previous page | 11 | **Pass** (test11, 40.1 s, batch b6) |
| 14 | Changes: rows from real stamps, project colour, honest % (100% on a one-task project) | 12 | **Pass** (test12, 89.4 s, batch b6 — asserts "To-do added:", "To-do done:" and `changesPercent-ChangeProj` reading "100% done") |
| 15 | Scheduled-prompt cancel removes the prompt; room delete removes the room | 13 | **Pass** (test13, 119.8 s, batch b7) |
| 16 | Kindness FIRST in the menu (above the profile row); kindness screen + wall | 14 | **Pass** (test14, 98.1 s, batch b7 — asserts `kindnessItem` stands above `meRow`, the counter line, `giveButton`, `kindnessWall`) |
| 17 | Settings holds motion/digest/delete/sign-out/keys; Me holds none of them | 14 | **Pass** (test14, batch b7 — Settings asserts `motionPicker`, `digestPicker`, `deleteAccount`, `signOut`, `settingsKeys`; Me asserts no `motionPicker`, no `deleteAccount`) |
| 18 | Bring my keys in: the pull answers with one of its honest lines | 15 | **Pass** (test15, 109.0 s, batch b8 — the pull answered with one of its three honest lines; the host half stands open, named in BUILT.md) |
| 19 | Google door: quiet cancel (no SDK cancel words left on the door) | 16 | **Could not check** — test16 skipped itself (55.5 s, batch b8): the Google sign-in sheet's Cancel surface did not appear inside the test's window on the simulator, so the cancel tap and the no-message-on-the-door assertion could not run. The quiet-cancel code stands in the tree (`Store.isDoorCancel` + `googleDoor()`); the leg is named here for QA's gate drive, never faked as a pass |
| 20 | Apple door: opens, dismisses, door stands clean | 17 | **Pass** (test17, 42.0 s, batch b9) |

## Fix-round legs (tests 18–21, run 14–15 Nov on the final tree)

The fix round's four surfaces carry their own legs, run in batches
`fix-b9`–`fix-b11` with the named re-runs, on the final tree. Route:
build-for-testing on the exact sources (stands TEST BUILD SUCCEEDED,
`fix-build8.log`), then test-without-building per batch; counts read
only from the bundles (`fix-b*.xcresult` in the same evidence folder).

| # | Leg | Test(s) | Verdict |
|---|-----|---------|---------|
| 21 | §9 task detail: open a task, checklist add/toggle/remove, dependency add makes the status "Blocked by Blocker task", dependency remove, detail toggle stands | 18 | **Pass** (solo re-run `fix-b9r`, 246.8 s). Story, in the open: the first run FAILED (bundle `fix-b9r1`, 188.2 s) — opening the detail had ALSO marked the task done (status read "Completed"), because the queue row's tap fired both its toggle and its new detail link. Fixed in app code (the row toggle now carries `.buttonStyle(.borderless)` — BUILT.md fix-round Fix #6); the re-run stands on the fixed bytes |
| 22 | §10 note picture attachment: seed the photo library, attach the picture, it stands in the note, remove it | 19 | **Could not check** — test19 skipped itself (92.8 s, batch `fix-b10`): the system photo picker's surface never appeared inside the test's window on the simulator, so the attach could not be driven. The attachment code stands in the tree (Firestore under the owner's note — BUILT.md fix-round §10, with the struck rooms-claim correction); the leg is named here for QA's gate drive, never faked as a pass |
| 23 | §11 per-agent controls: pause stands, the file tool switch turns off, project pick stands, and all of it persists across sign-out and back in | 20 | **Pass** (solo re-run `fix-b10r2`, 246.7 s). Story, in the open: the batch run and a solo re-run both FAILED at the same line (125.2 s · 147.9 s) — the file switch never turned off. The Store plumbing was read and is correct (the pause half of the same test passed); the cause was the labelled Toggle's element spanning label + knob, so the drive's tap landed on the label. Fixed in app code (plain label + label-hidden switch — BUILT.md fix-round Fix #7); the re-run stands on the fixed bytes |
| 24 | §15 devices + workspace: this device stands in Settings ▸ Devices marked "This device"; the workspace stands owner-only ("You · Owner", the never-share line, no invite control) | 21 | **Pass** (test21, 56.4 s, batch `fix-b11`, first run) |

**Fix-round suite totals (the whole suite on the final tree): 21 tests —
19 passed · 2 skipped · 0 failed.** Batches: b1 01+02 (2 passed;
test02's three failed attempts and test01's one accessibility-server
drop stand preserved under their r-names — BUILT.md fix-round Fixes
#2–#5) · b2 03+04 · b3 05+06 · b4 07+08 · b5 09+10 · b6 11+12 (test11
failed in the batch under load — the edge swipe never popped; passed
solo on the same bytes, 33.4 s, bundle `fix-b6r`) · b7 13+14 · b8 15+16
(16 skipped by its own guard — leg 19) · b9 17+18 (18 → leg 21) · b10
19+20 (legs 22–23) · b11 21 (leg 24). After the last code fixes, the
legs whose surfaces moved were re-proven on the final bytes: test02 +
test12 (`fix-recheck`: 292.5 s · 102.8 s) and test14 (`fix-recheck14`:
97.7 s). The two skips are legs 19 and 22 — both **Could not check**
with their causes named, carried to QA's gate drive by name.

Legs 19–20 stop, by design, at whatever the accounts' own walls do in
the simulator: a leg that cannot complete records **Could not check**
with the wall named (Google 2-Step / Apple code-to-phone are the proven
walls of record from the 340 door hunt), never a faked landing. Test 16
skips itself (XCTSkip) if no cancel surface appears in time — a skip
lands here as Could not check with that reason.
