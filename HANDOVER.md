# NeedsMe Connect Part 1 overlay: accounts, Loop, prompts and notes, theme law, icon law, name law fix (Addendum 5)

Apply: extract over the repo root. Changed: NeedsMe/{ConnectView,Store,ProjectViews,TasksView,RoomView,NotesView,HomeView,Theme,NeedsMeApp,RootView,PipTour}.swift (HomeView and RootView changed again for the name law), NeedsMeUITests/NeedsMeUITests.swift, ios-native.tar.gz. Added: NeedsMe/{AIKeys,AIClient,RoomView,PromptSender,SproutIcons}.swift (AIKeys, AIClient, RoomView came in earlier passes; PromptSender is new). No project.pbxproj, no version bump. Nothing was compiled or run (no Xcode here); syntax checked with tree-sitter only. The host proof judges each piece.

## Piece 4 storage truth (read from the code first)
Notes live in Firestore at users/{uid}/notes and prompts at users/{uid}/prompts, read by snapshot listeners in Store.listen(). Nothing about notes is device only. Alert settings and colours are on the phone (as shipped) but they are not notes. No move was needed. Old shape: title, body, project (string, "Unsorted" if none), ai, createdAt, updatedAt, version.
Rule made real: the old `Store.delete(_ note)` and the Delete button on the note card are removed. No delete button, no swipe to delete, no store call removes a note record. The only notes deletion left is Delete my account, which clears the whole space as shipped. I also added "prompts" to that clear list, because it left prompts behind before.
BUILT.

## Piece 1: auto project match. BUILT
After a note or prompt is saved, the first connected account (label order) reads it with the strict rule (only what is clearly stated, never invent) and may only pick one of her existing projects, JSON `{"project": string or null, "words": string}`. Unparsable, null, a name not in her list, or empty words means no project. The item is stamped with the reader label and the matched words ("Matched to X by Y. Words used: ..."). A project menu on every item lists her projects plus None. Her pick overrides, shows "Project set by you.", sets projectFixed, and the auto match never writes over it. Auto only runs on items with no project, or whose project the auto match itself set. Notes keep a list of project names (`projects`; a project is its name in this app); auto adds at most one. Old items keep `project` as the first name.
Removed: the old "Looks like this belongs in X. Save here" text suggestion in the editor, replaced by the reader.

## Piece 2: scheduled send, exact time. BUILT
Prompt record: title, body (text), room (id), roomTitle, state ("scheduled" or "sent"), scheduledFor, sentAt. Send now: one tap in the prompt editor (or on a prompt card) posts it into its room as her message, stamps sentAt, state becomes Sent. Schedule: date and time picker in the same editor, one tap. An in-app timer checks every 5 seconds while the app is open and fires due prompts the same way, then posts one system line in the room: "Scheduled prompt <title>. Set for <time>. Sent at <time>." The room wake follows: the room's own engine if open, otherwise a short lived engine (retired when she opens the room or after 5 minutes). Honest split, shown on the schedule screen: "Sends at this time while NeedsMe is open. Closed app sending comes with the server wake." A closed app sends nothing at the set time; the Part 2 server relay is not in this build and the app never promises it. If the app is opened after the set time, the prompt fires then, and the system line shows both times.
Removed from the prompt editor: the "Best for which AI?" picker (the target is now a room). Old prompts keep their ai field. Old prompts with no state show under Prompts Scheduled as "Not scheduled yet. Edit it to pick a room and a time."

## Piece 3: notes like iPhone Notes. BUILT, with two parts not built
Built: the + on Notes opens a blank note already typing, no title field (title is the first line). Web addresses open on tap in the saved note. Checklist lines ("- [ ]" and "- [x]" in the text) tick in the saved note and save at once. Archive and an Archived list with one tap Restore (whole record). A note holds a list of projects, added or removed by hand. Three labelled places as buttons: Prompts Sent, Prompts Scheduled, Notes, never mixed.
NOT built: tables and drawing. Reason: neither fits cleanly in this pass without a new storage shape and a canvas view, and neither was a must. Also not built: pressing Return on a checklist line does not start the next line automatically; a button adds a new checklist line.

## Tests
test08 (UI standing only): the three places show, the + opens a note that is already typing, and the note editor has no delete control. test02 was updated to the new note flow. No live calls.

## Theme law (Addendum 4). BUILT
Picks by name: White (default, today's Soft White renamed, same colours), Dark (unchanged), Beige, Brand, then Device as the extra pick. Raw values: white, dark, beige, brand, system.
Migration: a stored "green" (Soft Green) value reads as Brand. On the device it is rewritten to "brand" at launch; in her cloud space it is rewritten to "brand" when read. Unknown or empty reads as White.
Storage shape: AppStorage key `nm_theme` on the device (instant copy, as before) AND Firestore users/{uid}/settings/app with field `theme` (plus updatedAt). No per user settings shape existed in Store.swift before, so this one is new. Any pick (More screen) writes both. On sign in the app listens to that document; the cloud pick wins over the device one and also follows a change made on another device. A signed in account with nothing saved gets White (the device copy is set to White, nothing is uploaded until she picks). The device copy of an older account's local pick is therefore not uploaded; she picks once and it is kept. Delete my account clears `settings` with the rest of her space.
Beige: bg E6D8BC, card F3EAD6, ink 2A1F10, soft 57472E, accent 7A4E1D, accent ink FFF8EA, chip D6C4A0. Brand (Sprout tokens already in Theme.swift: accent A8C256, warm black 16120E): bg DCE8B4, card F6FAE8, ink 16120E, soft 44512A, accent A8C256, accent ink 16120E, chip C4D88A.
Contrast (repo's ios-native/contrast.py, AA needs 4.5), all pass. Worst pairs: beige accent ink on accent 6.77, beige ink on chip 9.42, beige soft on bg 6.36; brand soft on bg 6.61, brand ink on chip 12.01, brand accent ink on accent 9.33. White and Dark unchanged: worst white soft on bg 5.25, dark soft on card 5.97. No pick fails AA.
The Pip tour colour line now names White, Dark, Beige, Brand. The delete account text and the privacy line now say the colour pick is in her account.
test09: the picker shows White, Dark, Beige and Brand by name and Soft Green is gone. test03 theme loop updated to the new names. No live calls.

## Standing law from Ilse: Pip and Sprout icons, two taps, plain words
No emojis anywhere in the code or copy I added. Stock glyphs: removed from every surface I built or touched in this round and replaced with icons drawn in the Pip brand style (warm black rounded forms, sprout leaf pair in 0xA8C256, curves taken from the Pip art). They are drawn in code (NeedsMe/SproutIcons.swift), so there are no new asset files.
Icons I created (3): `SproutLeaves` (the two leaves and stem, same curves as the Pip sprout), `SproutBox` (checklist and task box: ink outline off, filled ink with green sprout on), `SproutPlus` (green rounded square with an ink plus, the "new" mark).
Where they replaced stock glyphs: note checklist ticks, the + on Notes (prompts and notes), the + on Tasks, the task done mark on the Tasks list and the project page, and the selected mark on the colour picker. The project menu on notes and prompts has no glyph now; it reads "Put on <project>", "Take off <project>" and "No project".
Stock glyphs still in the app, all from before this round and not touched: the tab bar icons (Home, Tasks, Notes, AI, More), the Google and email glyphs on the sign in screen. They are not new surfaces, so I left them; say if you want them redrawn.
Flows, taps from the tab (typing and picking a time not counted):
- New note: Notes, + (1 tap), already typing. Done is a second tap.
- Checklist line: + (1), Add a checklist line (2). Tick a line: open the note (1), tick (2).
- Archive: Archive on the note card (1). Restore: Archived (1), Restore (2). Archive from inside a note: open (1), Archive (2).
- Fix a project: the project button on the item (1), pick (2).
- Send a prompt now: + (1), Send now (2). This needs a guess: the room defaults to the first room in the list.
- Schedule a prompt: + (1), Schedule (2). This needs a guess: the time defaults to one hour from now. Choosing another room or time takes more taps (open the room picker, pick the room, set the date and time).
- Send a saved prompt now: Send now on its card (1).
- Pick a colour: More, tap the colour (1 tap, they are listed on the More screen).
- File this talk and Show the list: AI tab, Open rooms (1), the room (2), File this talk (3). THIS FLOW TOOK THREE TAPS, one more than the law. The room has to be opened first. A shortcut would put a File button on the room list, not built in this round.
- Account flows (Add another account, Test connection): AI tab, scroll to the provider, tap (1 to 2 taps, plus scrolling on the Connect screen).

## Name law fix (Addendum 5). BUILT
Where the ask lives: RootView. After the Pip guide is closed, a signed in user with no saved name sees a Pip card at the bottom: "What's your name?", a name field, Save, and a close control in plain words, "Not now". It does not block the tabs. A missing name blocks nothing.
Cadence: closed unanswered, it is offered once more on the NEXT launch only, never the same session, then never again. Kept per user on the device (`nm_nameask_<uid>`: first close stores the launch it happened in, the next launch shows it once more, the next close stores done; Save also stores done). If the app is killed while the card is still showing it counts as not yet closed and shows again next launch.
Save shape: users/{uid}/settings/app, field `name`, beside `theme` (the shape built in the theme pass fits, no new record). Same Save also calls updateProfile on the sign in (Auth displayName). Both writes happen from one Store call (`saveName`), from the ask card and from More.
Edit in More: a "Your name" card with a row showing the saved name or "Add your name"; tap to edit, text field and Save (writes both stores).
Greeting order, used by the Home greeting "Hello, <name>" (the only screen that addresses her): her space name, then the sign in displayName, then "friend". Google and Apple users start from their displayName and edit it the same way. An empty or blank name counts as none.
Switching accounts: the saved name is cleared when the signed in user changes and reloaded from that account's own space, so a second account never shows the first one's name.
Nothing hardcoded: no person name added anywhere. Count of "Ilse" in app sources: 0.
Delete my account still clears settings, so the name goes with the rest of her space.
Flow taps: the ask is on screen with no tap, Save is 1 tap after typing. More, name row (1), Save (2). Both within two taps.
test10: the name ask card stands with its field, Save and Not now, and the More name row shows "Add your name". Because the ask card would cover other tests, the other tests launch with `-uitest-noask`; test10 launches without it. No live calls.
Icons: the ask card reuses the existing Pip image; no new icon, no stock glyph.

## Earlier passes (unchanged): accounts, Loop (steps 2 to 5 built), Part E
Part E: no accounts or keys created; Google sign-in stopped at the password step.

## Tarball parity
ios-native.tar.gz repacked: 36 entries (35 before plus SproutIcons.swift), every file equal to the tree. The 15 pre-existing tree-only entries are untouched: GAPS.md, PLAN-2026-11-09.md, project.yml-E, NeedsMe.xcodeproj plus 9 children, NeedsMe/Info.plist, NeedsMe/NeedsMe.entitlements.
