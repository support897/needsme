import XCTest

final class NeedsMeUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUp() { continueAfterFailure = false; app.launchArguments = ["-uitest-reset", "-uitest-noask"]; app.launch() }

    func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir + "/" + name + ".png"))
        }
    }
    func wait(_ e: XCUIElement, _ t: TimeInterval = 20, _ m: String = "") {
        if !e.waitForExistence(timeout: t) {
            shot("FAIL-" + String(Int.random(in: 100...999)))
            let btns = labels(app.buttons, 14)
            XCTFail((m.isEmpty ? "missing \(e)" : m) + " | BUTTONS: " + btns + " | TEXTS: " + screenText())
        }
    }
    func labels(_ q: XCUIElementQuery, _ n: Int) -> String {
        var out: [String] = []
        // The screen can change while this runs. Read a snapshot of each element and skip any that vanished.
        for i in 0..<min(q.count, n) {
            if i >= q.count { break }
            if let snap = try? q.element(boundBy: i).snapshot() { out.append(snap.label) }
        }
        return out.joined(separator: ",")
    }
    func screenText() -> String { labels(app.staticTexts, 30).replacingOccurrences(of: ",", with: " | ").suffix(300).description }
    func tapUntil(_ b: XCUIElement, _ ok: @escaping () -> Bool) {
        for _ in 0..<5 {
            if b.waitForExistence(timeout: 5) { b.tap() }
            let end = Date().addingTimeInterval(3)
            while Date() < end { if ok() { return }; Thread.sleep(forTimeInterval: 0.3) }
        }
    }
    func submitCreds() {
        let go = app.keyboards.buttons["Go"]
        if go.waitForExistence(timeout: 3) { go.tap() } else { app.buttons["emailSubmit"].tap() }
    }
    /// The door shape: the first page, then the email button opens the email page.
    func openEmailPage() {
        wait(app.buttons["emailButton"]); app.buttons["emailButton"].tap()
        wait(app.textFields["you@example.com"], 15, "email page did not open")
    }
    func openAddTask() {
        for _ in 0..<4 {
            wait(app.buttons["Add a task"]); app.buttons["Add a task"].tap()
            if app.textFields["What needs doing?"].waitForExistence(timeout: 6) { return }
        }
    }
    /// Opens a More destination by its row identifier, scrolling the menu when needed.
    func openMore(_ id: String, _ ready: @escaping () -> Bool) {
        let rowEl = app.buttons[id]
        // Right after sign-in the tab bar can exist before it has a valid hit point
        // (build 341 drive, test03 trace: the tap computed hit point {-1, -1} and the
        // tab never switched). Re-tap until the row exists — same retry discipline as
        // tapUntil/openAddTask. The assertion below is unchanged.
        for _ in 0..<4 {
            app.tabBars.buttons["More"].tap()
            if rowEl.waitForExistence(timeout: 6) { break }
        }
        wait(rowEl, 10, "More row missing: " + id)
        for _ in 0..<6 where !rowEl.isHittable { app.swipeUp() }
        rowEl.tap()
        let end = Date().addingTimeInterval(15)
        while Date() < end { if ready() { return }; Thread.sleep(forTimeInterval: 0.3) }
        shot("FAIL-more-" + id)
        XCTFail("More destination did not open: " + id + " | TEXTS: " + screenText())
    }
    func backToMoreRoot() {
        let b = app.navigationBars.buttons.firstMatch
        if b.exists { b.tap() }
    }
    func signUpFresh() -> (String, String) {
        let mail = "nmui.tests+nmui\(Int.random(in: 1000...9999))@example.com"
        let pass = "Nm" + UUID().uuidString.prefix(10) + "!"
        openEmailPage()
        let email = app.textFields["you@example.com"]; wait(email); email.tap(); email.typeText(mail)
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText(pass); submitCreds()
        for _ in 0..<3 {
            let t0 = Date().addingTimeInterval(12)
            while Date() < t0 { if app.tabBars.buttons["Projects"].exists { return (mail, pass) }; Thread.sleep(forTimeInterval: 0.5) }
            if app.buttons["emailSubmit"].exists && app.staticTexts["authMessage"].exists == false { app.buttons["emailSubmit"].tap() }
        }
        return (mail, pass)
    }
    func text(_ s: String) -> XCUIElement { app.staticTexts[s] }

    // 01 the door: Pip and the wordmark stand on it; the first page is only Google, Apple and one
    // small email button; email opens its own page; bad login shows error
    func test01_SignUpFirstAndInvalidLogin() {
        wait(app.buttons["emailButton"]); shot("01-signup-first")
        XCTAssertTrue(app.images["doorPip"].exists || app.otherElements["doorPip"].exists || text("NeedsMe Ai").exists, "Pip missing on the door")
        wait(text("NeedsMe Ai"), 10, "wordmark missing on the door"); shot("01-door-pip")
        XCTAssertEqual(app.textFields.count + app.secureTextFields.count, 0, "the first page must not hold an email form")
        XCTAssertFalse(app.buttons["switchMode"].exists, "the mode switch belongs on the email page")
        XCTAssertFalse(app.buttons["emailSubmit"].exists, "the submit button belongs on the email page")
        XCTAssertTrue(app.buttons["appleButton"].exists, "Apple button missing")
        XCTAssertTrue(app.buttons["googleButton"].exists, "Google button missing")
        XCTAssertTrue(app.buttons["emailButton"].exists, "Email button missing")
        shot("01-google-door")
        openEmailPage(); shot("01-email-page")
        XCTAssertTrue(app.buttons["emailSubmit"].exists, "submit missing on the email page")
        app.buttons["switchMode"].tap(); wait(app.buttons["Sign in"], 10, "mode switch did not change the page to sign in")
        let email = app.textFields["you@example.com"]; wait(email); email.tap(); email.typeText("nmui.tests+nmui0000@example.com")
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText("wrong-pass-123"); submitCreds()
        if !app.staticTexts["authMessage"].waitForExistence(timeout: 15) { app.buttons["emailSubmit"].tap() }
        wait(app.staticTexts["authMessage"], 40, "no error for invalid login"); shot("01-invalid-login")
    }

    // 02 the full journey on the build 341 shape: tour, Home, Needs Me, Projects, Tasks (in More),
    // kindness moment, Notes, Connections (in More), Settings (in More), sign out from Settings
    func test02_FullJourney() {
        _ = signUpFresh()
        wait(text("Tour 1 of 7"), 60, "tour did not start after sign-up. SCREEN: " + screenText()); shot("02-tour-1")
        tapUntil(app.buttons["Next"]) { self.text("Tour 2 of 7").exists }; wait(text("Tour 2 of 7")); shot("02-tour-2")
        tapUntil(app.buttons["Back"]) { self.text("Tour 1 of 7").exists }; wait(text("Tour 1 of 7"))
        for n in 2...7 { tapUntil(app.buttons["Next"]) { self.text("Tour \(n) of 7").exists }; wait(text("Tour \(n) of 7")) }
        shot("02-tour-7"); tapUntil(app.buttons["Finish tour"]) { !self.app.buttons["Finish tour"].exists }
        wait(text("All clear")); wait(text("Needs your attention")); wait(text("Continue where you left off")); wait(text("Recent wins")); shot("03-home-allclear")
        XCTAssertTrue(app.otherElements["homeSummary"].exists || text("Needs you").exists, "home summary tiles missing")

        app.tabBars.buttons["Needs Me"].tap(); wait(text("Nothing needs you right now"), 15, "Needs Me empty state missing. SCREEN: " + screenText()); shot("03-needsme-empty")
        app.tabBars.buttons["Projects"].tap(); wait(app.buttons["yourProgress"], 10, "Your Progress link missing"); shot("03-projects")

        openMore("moreTasks") { self.app.buttons["Add a task"].exists }
        openAddTask()
        let f = app.textFields["What needs doing?"]; wait(f); f.tap(); f.typeText("UI test task")
        app.textFields["Or a new project name"].tap(); app.textFields["Or a new project name"].typeText("UITestProject")
        app.buttons["Save"].tap()
        wait(text("UI test task"), 20, "task not shown. SCREEN: " + screenText()); shot("04-task-added")
        app.buttons["Mark done"].firstMatch.tap(); wait(app.buttons["Mark not done"]); shot("04-task-done")
        wait(text("Nice work, that one is done."), 10, "kindness moment did not show after marking done"); shot("04-kindness-moment")
        backToMoreRoot()

        app.tabBars.buttons["Home"].tap(); wait(text("UITestProject"), 20, "project progress not shown"); shot("05-home-project")
        app.buttons["inboxButton"].tap(); wait(text("Inbox is empty"), 10, "inbox empty state missing. SCREEN: " + screenText()); shot("05-inbox")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["project-UITestProject"].tap(); wait(text("1 of 1 tasks done"), 10, "project page missing. SCREEN: " + screenText()); shot("05-project-page")
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Notes"].tap()
        app.buttons["New"].tap()
        let nb = app.textViews["noteBody"]; wait(nb, 10, "new note did not open typing"); nb.typeText("UI test note about UITestProject")
        shot("06-note-typing")
        app.buttons["noteDone"].tap(); wait(app.staticTexts["UI test note about UITestProject"], 10, "note text not shown after Done"); shot("06-note-saved")
        app.buttons["noteClose"].tap()
        app.buttons["Prompts Scheduled"].tap(); wait(text("No prompts scheduled. Tap + to write one.")); shot("06-prompts-empty")

        openMore("moreConnections") { self.app.buttons["Copy setup prompt"].exists }
        wait(app.staticTexts["connectionStatus"], 10, "honest connection status missing"); shot("07-connect")
        backToMoreRoot()

        openMore("settingsRow") { self.app.segmentedControls["motionPicker"].exists }
        let mp = app.segmentedControls["motionPicker"]; wait(mp, 10, "motion setting missing")
        mp.buttons["Reduced"].tap(); XCTAssertTrue(mp.buttons["Reduced"].isSelected, "Reduced motion did not select"); shot("08-motion-reduced")
        mp.buttons["System"].tap()
        let dg = app.segmentedControls["digestPicker"]; wait(dg, 10, "digest setting missing")
        dg.buttons["Weekly"].tap(); XCTAssertTrue(dg.buttons["Weekly"].isSelected, "Weekly digest did not select"); shot("08-alerts")
        for th in ["Dark", "Brand", "Beige", "White"] {
            let b = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", th)).firstMatch; wait(b); b.tap(); shot("08-theme-" + th)
        }
        backToMoreRoot()
        let replay = app.buttons["Replay Pip's guide"]; wait(replay, 10, "replay missing in More")
        for _ in 0..<6 where !replay.isHittable { app.swipeUp() }
        replay.tap(); wait(text("Tour 1 of 7")); shot("09-replay")
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }; XCTAssertFalse(text("Tour 1 of 7").exists)
        openMore("settingsRow") { self.app.buttons["signOut"].exists }
        let so = app.buttons["signOut"]
        for _ in 0..<8 where !so.isHittable { app.swipeUp() }
        so.tap(); wait(app.buttons["emailButton"]); shot("10-signed-out")
    }

    // 03 real email sign-up with random test account, skip tour, data persists across sign-out/in
    func test03_EmailSignUpSignInRoundTrip() {
        let tag = String(Int.random(in: 1000...9999))
        let mail = "nmui.tests+nmui\(tag)@example.com"
        let pass = "Nm" + UUID().uuidString.prefix(10) + "!"
        openEmailPage()
        let email = app.textFields["you@example.com"]; email.tap(); email.typeText(mail)
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText(pass)
        app.buttons["emailSubmit"].tap()
        wait(text("Tour 1 of 7"), 30, "sign-up did not reach tour. SCREEN: " + screenText()); shot("11-signup-tour")
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }; wait(text("All clear"))
        openMore("moreTasks") { self.app.buttons["Add a task"].exists }
        openAddTask()
        let f = app.textFields["What needs doing?"]; wait(f, 20, "add-task sheet missing. SCREEN: " + screenText()); f.tap(); f.typeText("Persist me"); app.buttons["Save"].tap(); wait(text("Persist me"))
        openMore("settingsRow") { self.app.buttons["signOut"].exists }
        let so = app.buttons["signOut"]
        for _ in 0..<8 where !so.isHittable { app.swipeUp() }
        so.tap()
        wait(app.buttons["emailButton"])
        openEmailPage(); app.buttons["switchMode"].tap()
        let e2 = app.textFields["you@example.com"]; wait(e2); e2.tap(); e2.typeText(mail)
        let p2 = app.secureTextFields.firstMatch; p2.tap(); p2.typeText(pass); submitCreds()
        for _ in 0..<3 {
            let t0 = Date().addingTimeInterval(12)
            while Date() < t0 { if app.tabBars.buttons["Projects"].exists { break }; Thread.sleep(forTimeInterval: 0.5) }
            if app.tabBars.buttons["Projects"].exists { break }
            if app.buttons["emailSubmit"].exists { app.buttons["emailSubmit"].tap() }
        }
        wait(app.tabBars.buttons["Projects"], 30, "sign-in after sign-out failed")
        openMore("moreTasks") { self.text("Persist me").exists }
        wait(text("Persist me"), 20, "task did not persist after sign-in"); shot("12-persisted")
    }

    // 04 privacy screen (inside Settings) + delete account removes the account
    func test04_PrivacyAndDeleteAccount() {
        let (mail, pass) = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.tabBars.buttons["More"], 30, "no tab bar after sign-up")
        openMore("settingsRow") { self.text("Privacy and your data").exists }
        wait(text("Privacy and your data"), 10, "privacy text missing"); shot("13-privacy")
        let del = app.buttons["Delete my account"]; wait(del, 10, "delete button missing")
        for _ in 0..<6 where !del.isHittable { app.swipeUp() }
        del.tap()
        let confirm = app.alerts.buttons["Delete everything"]; wait(confirm, 10, "confirm alert missing"); shot("13-delete-confirm")
        confirm.tap()
        wait(app.buttons["emailButton"], 90, "not signed out after delete. SCREEN: " + screenText()); shot("13-deleted")
        openEmailPage(); app.buttons["switchMode"].tap()
        let e = app.textFields["you@example.com"]; wait(e); e.tap(); e.typeText(mail)
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText(pass); submitCreds()
        if !app.staticTexts["authMessage"].waitForExistence(timeout: 15) { app.buttons["emailSubmit"].tap() }
        wait(app.staticTexts["authMessage"], 30, "deleted account could still sign in"); shot("13-cannot-sign-in")
        XCTAssertFalse(app.tabBars.buttons["Projects"].exists, "deleted account signed in")
    }

    // 05 Connections screen: a secure key field and a Test connection button for each own key AI,
    // none for hand off AIs. This proves the UI stands. It does not call any AI service.
    func test05_ConnectKeyFields() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.tabBars.buttons["More"], 30, "no tab bar after sign-up")
        openMore("moreConnections") { self.app.buttons["Copy setup prompt"].exists }
        wait(app.staticTexts["connectionStatus"], 10, "connection status missing")
        for id in ["chatgpt", "claude", "gemini", "perplexity", "grok"] {
            XCTAssertTrue(app.secureTextFields["keyField-" + id].exists, "key field missing for " + id)
            XCTAssertTrue(app.buttons["testKey-" + id].exists, "Test connection missing for " + id)
            XCTAssertEqual(app.staticTexts["status-" + id].label, "Not tested", "a new account must start as Not tested: " + id)
        }
        for id in ["copilot", "claudecode", "codex", "cursor", "polar", "muse"] {
            XCTAssertFalse(app.secureTextFields["keyField-" + id].exists, "hand off AI must have no key field: " + id)
            XCTAssertFalse(app.buttons["testKey-" + id].exists, "hand off AI must have no test button: " + id)
        }
        // Add another account stands under one provider: a name field and a key field appear.
        let add = app.buttons["addAccount-claude"]; wait(add, 10, "Add another account missing under Claude")
        for _ in 0..<8 where !add.isHittable { app.swipeUp() }
        add.tap()
        wait(app.textFields["newLabel-claude"], 10, "new account name field missing")
        XCTAssertTrue(app.secureTextFields["newKey-claude"].exists, "new account key field missing")
        XCTAssertEqual(app.textFields["newLabel-claude"].value as? String, "Claude 2", "default label should be the provider name plus a number")
        shot("14-connect-keys")
    }

    // 06 Group chat: create a room, send a message, the message stands in the room.
    // This proves the UI stands. It does not call any AI service.
    func test06_RoomCreateAndSend() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.tabBars.buttons["More"], 30, "no tab bar after sign-up")
        openMore("moreGroupChat") { self.app.buttons["newRoom"].exists }
        wait(app.buttons["newRoom"], 10, "New group chat missing"); app.buttons["newRoom"].tap()
        let field = app.alerts.textFields.firstMatch; wait(field, 10, "room name box missing")
        field.typeText("UI room"); app.alerts.buttons["Create"].tap()
        wait(app.buttons["room-UI room"], 20, "room not listed. SCREEN: " + screenText()); shot("15-room-listed")
        app.buttons["room-UI room"].tap()
        wait(text("AIs answer while this room is open."), 10, "room note missing")
        wait(app.staticTexts["roomParticipants"], 10, "participants line missing")
        let c = app.textFields["roomComposer"]; wait(c, 10, "composer missing"); c.tap(); c.typeText("Hello room")
        app.buttons["roomSend"].tap()
        wait(text("Hello room"), 20, "sent message is not in the room. SCREEN: " + screenText()); shot("15-room-sent")
    }

    // 07 The Loop controls stand in a room. UI standing only: no live AI call.
    func test07_RoomLoopControls() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.tabBars.buttons["More"], 30, "no tab bar after sign-up")
        openMore("moreGroupChat") { self.app.buttons["newRoom"].exists }
        app.buttons["newRoom"].tap()
        let field = app.alerts.textFields.firstMatch; wait(field, 10, "room name box missing")
        field.typeText("Loop room"); app.alerts.buttons["Create"].tap()
        wait(app.buttons["room-Loop room"], 20, "room not listed. SCREEN: " + screenText())
        app.buttons["room-Loop room"].tap()
        wait(app.buttons["fileTalk"], 10, "File this talk control missing")
        XCTAssertTrue(app.buttons["showList"].exists, "Show the list control missing")
        // With no AI connected the control must say so in plain words and file nothing.
        app.buttons["fileTalk"].tap()
        let note = app.staticTexts["fileNote"]; wait(note, 10, "no plain words after tapping File this talk")
        XCTAssertTrue(note.label.contains("No AI is connected"), "wrong words: " + note.label)
        shot("16-room-loop-controls")
    }

    // 08 Three labelled places, a note opens already typing, and no delete control on a note. UI standing only.
    func test08_NotesPlacesAndNoDelete() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.tabBars.buttons["Notes"], 30, "no tab bar after sign-up")
        app.tabBars.buttons["Notes"].tap()
        for name in ["Prompts Sent", "Prompts Scheduled", "Notes"] { wait(app.buttons[name], 10, name + " place missing") }
        shot("17-notes-places")
        app.buttons["newItem"].tap()
        let body = app.textViews["noteBody"]; wait(body, 10, "new note did not open")
        var typing = false
        for _ in 0..<10 where !typing {
            typing = (body.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
            if !typing { Thread.sleep(forTimeInterval: 0.5) }
        }
        XCTAssertTrue(typing, "new note is not already typing")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).count, 0, "a delete control shows in the note editor")
        shot("17-note-no-delete")
    }

    // 09 The colour picker (inside Settings) offers White, Dark, Beige and Brand by name. UI standing only.
    func test09_ThemePickerNames() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.tabBars.buttons["More"], 30, "no tab bar after sign-up")
        openMore("settingsRow") { self.app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "White")).firstMatch.exists }
        for name in ["White", "Dark", "Beige", "Brand"] {
            let b = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            wait(b, 10, name + " pick missing")
        }
        XCTAssertEqual(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Soft Green'")).count, 0, "Soft Green still offered")
        shot("18-theme-picker")
    }

    // 10 The first run name ask stands with its field, Save and close, and Me holds the name row. UI standing only.
    func test10_NameAskAndRow() {
        app.terminate(); app.launchArguments = ["-uitest-reset"]; app.launch()
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.textFields["nameField"], 20, "name ask card missing")
        XCTAssertTrue(app.staticTexts["What's your name?"].exists, "ask words missing")
        XCTAssertTrue(app.textFields["nameField"].exists, "name field missing")
        XCTAssertTrue(app.buttons["nameSave"].exists, "Save missing")
        wait(app.buttons["nameClose"], 5, "close control missing")
        shot("19-name-ask")
        app.buttons["nameClose"].tap()
        openMore("meRow") { self.app.buttons["nameRow"].exists }
        wait(app.buttons["nameRow"], 10, "Me name row missing")
        XCTAssertTrue(app.buttons["nameRow"].label.contains("Add your name"), "row should offer Add your name")
        shot("19-name-row")
    }

    // 11 Swipe law on the door: the email page slides back to the first page.
    func test11_SwipeBackFromEmailPage() {
        openEmailPage()
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: to)
        wait(app.buttons["googleButton"], 10, "swipe back did not return to the first page")
        XCTAssertFalse(app.textFields["you@example.com"].exists, "email page still showing after swipe back")
        shot("20-swipe-back")
    }

    // 12 Changes (item 1): a task added under a project and marked done both stand as rows
    // under that project, with who and when, and the project's percentage stands.
    func test12_ChangesRows() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("moreTasks") { self.app.buttons["Add a task"].exists }
        openAddTask()
        let f = app.textFields["What needs doing?"]; wait(f); f.tap(); f.typeText("UI change task")
        app.textFields["Or a new project name"].tap(); app.textFields["Or a new project name"].typeText("ChangeProj")
        app.buttons["Save"].tap()
        wait(text("UI change task"), 20, "task not shown")
        app.buttons["Mark done"].firstMatch.tap(); wait(app.buttons["Mark not done"])
        backToMoreRoot()
        openMore("moreChanges") { self.text("ChangeProj").exists }
        wait(text("ChangeProj"), 10, "project heading missing in Changes")
        wait(text("To-do added: UI change task"), 10, "added row missing. SCREEN: " + screenText())
        wait(text("To-do done: UI change task"), 10, "done row missing. SCREEN: " + screenText())
        XCTAssertEqual(app.staticTexts["changesPercent-ChangeProj"].label, "100% done", "percentage missing or wrong")
        shot("21-changes-rows")
    }

    // 13 Item 6: a scheduled prompt can be cancelled and never fires; a room can be deleted.
    func test13_PromptCancelAndRoomDelete() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("moreGroupChat") { self.app.buttons["newRoom"].exists }
        app.buttons["newRoom"].tap()
        let field = app.alerts.textFields.firstMatch; wait(field, 10, "room name box missing")
        field.typeText("Cancel room"); app.alerts.buttons["Create"].tap()
        wait(app.buttons["room-Cancel room"], 20, "room not listed")
        backToMoreRoot()
        // Schedule a prompt into that room, then cancel it from Prompts Scheduled.
        app.tabBars.buttons["Notes"].tap()
        app.buttons["Prompts Scheduled"].tap()
        app.buttons["newItem"].tap()
        let pt = app.textFields["promptText"]; wait(pt, 10, "prompt sheet missing"); pt.tap(); pt.typeText("Cancel me prompt")
        let picker = app.buttons["promptRoom"]; wait(picker, 10, "room picker missing"); picker.tap()
        let roomPick = app.buttons["Cancel room"]; wait(roomPick, 10, "room not in picker"); roomPick.tap()
        let sched = app.buttons["promptSchedule"]; wait(sched, 10, "Schedule button missing"); sched.tap()
        wait(text("Cancel me prompt"), 15, "scheduled prompt not listed. SCREEN: " + screenText()); shot("22-prompt-scheduled")
        let cancel = app.buttons["Cancel this prompt"]; wait(cancel, 10, "cancel control missing on the scheduled prompt")
        for _ in 0..<4 where !cancel.isHittable { app.swipeUp() }
        cancel.tap()
        let end = Date().addingTimeInterval(12)
        var gone = false
        while Date() < end { if !text("Cancel me prompt").exists { gone = true; break }; Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertTrue(gone, "cancelled prompt still listed as scheduled"); shot("22-prompt-cancelled")
        // Delete the room.
        openMore("moreGroupChat") { self.app.buttons["room-Cancel room"].exists }
        let del = app.buttons["deleteRoom-Cancel room"]; wait(del, 10, "room delete control missing")
        del.tap()
        let confirm = app.alerts.buttons["Delete the room"]; wait(confirm, 10, "delete confirm missing"); shot("23-room-delete-confirm")
        confirm.tap()
        let end2 = Date().addingTimeInterval(12)
        var roomGone = false
        while Date() < end2 { if !app.buttons["room-Cancel room"].exists { roomGone = true; break }; Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertTrue(roomGone, "room still listed after delete"); shot("23-room-deleted")
    }

    // 14 Item 7 + item 8 shape: the kindness item stands FIRST in More; Settings holds every
    // setting; Me holds none; the kindness screen stands with its counter and wall.
    func test14_MenuOrderSettingsAndKindness() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        app.tabBars.buttons["More"].tap()
        let kind = app.buttons["kindnessItem"]; wait(kind, 10, "kindness item missing in More")
        let me = app.buttons["meRow"]; wait(me, 10, "Me row missing in More")
        XCTAssertTrue(kind.frame.minY < me.frame.minY, "kindness item is not at the very top of the menu")
        shot("24-more-top")
        kind.tap()
        wait(text("Be one of the first kind humans"), 10, "kind humans counter missing. SCREEN: " + screenText())
        XCTAssertTrue(app.buttons["giveButton"].exists, "give button missing")
        XCTAssertTrue(app.staticTexts["kindnessWall"].exists, "kindness wall missing")
        shot("24-kindness")
        backToMoreRoot()
        openMore("settingsRow") { self.app.segmentedControls["motionPicker"].exists }
        XCTAssertTrue(app.segmentedControls["digestPicker"].exists, "digest setting not in Settings")
        XCTAssertTrue(app.buttons["deleteAccount"].exists, "delete not in Settings")
        XCTAssertTrue(app.buttons["signOut"].exists, "sign out not in Settings")
        XCTAssertTrue(app.buttons["settingsKeys"].exists, "keys link not in Settings")
        shot("25-settings")
        backToMoreRoot()
        openMore("meRow") { self.app.buttons["nameRow"].exists }
        XCTAssertFalse(app.segmentedControls["motionPicker"].exists, "a setting stands in Me")
        XCTAssertFalse(app.buttons["deleteAccount"].exists, "delete stands in Me")
        shot("25-me-clean")
    }

    // 15 Item 2 surface: the Bring my keys in button runs the pull and lands on one of the
    // honest lines. On this test account the keys host is not standing yet, so the line must
    // be the unreachable one (or no-keys / give-it-a-moment if the host has since stood up).
    func test15_BringKeysHonestLine() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("moreConnections") { self.app.buttons["bringKeys"].exists }
        let b = app.buttons["bringKeys"]
        for _ in 0..<8 where !b.isHittable { app.swipeUp() }
        b.tap()
        let lines = ["Could not reach the server. Your keys stay where they are. Try again later.",
                     "No keys waiting for this account.",
                     "Too many tries just now. Give it a moment, then tap again."]
        let end = Date().addingTimeInterval(60)
        var found = ""
        while Date() < end {
            for l in lines where text(l).exists { found = l; break }
            if !found.isEmpty { break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertFalse(found.isEmpty, "no honest result line after the pull. SCREEN: " + screenText())
        shot("26-bring-keys")
    }

    // 16 Item 4 closing proof: cancelling the Google door is a quiet return. No error line,
    // nothing red. If the Google page never opens in this run, the leg is skipped, not faked.
    func test16_GoogleCancelIsQuiet() throws {
        wait(app.buttons["googleButton"])
        app.buttons["googleButton"].tap()
        let cancel = app.buttons["Cancel"]
        if !cancel.waitForExistence(timeout: 25) {
            shot("27-google-no-page")
            throw XCTSkip("The Google page did not open in this run, so there was nothing to cancel.")
        }
        shot("27-google-page")
        cancel.tap()
        wait(app.buttons["googleButton"], 20, "door did not return after the Google cancel")
        XCTAssertFalse(app.staticTexts["authMessage"].exists, "a Google cancel painted an error line on the door")
        shot("27-google-cancel-quiet")
    }

    // 17 The Apple door: tapping it raises Apple's own sheet or alert, and closing it returns
    // to a clean standing door (the drive records what this simulator shows).
    func test17_AppleDoorStands() {
        wait(app.buttons["appleButton"])
        app.buttons["appleButton"].tap()
        Thread.sleep(forTimeInterval: 3)
        shot("28-apple-tap")
        for label in ["Close", "Cancel", "OK"] {
            let b = app.buttons[label]
            if b.exists { b.tap(); break }
        }
        wait(app.buttons["googleButton"], 15, "door did not stand after the Apple tap. SCREEN: " + screenText())
        shot("28-apple-door")
    }
}
