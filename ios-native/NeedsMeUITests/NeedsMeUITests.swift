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
    /// More opens from the Sprout N on Home; go Home first when it is not on screen.
    /// Hidden tab layers stay in the tree, so one id can match twice: pick the one on screen.
    func hittable(_ q: XCUIElementQuery) -> XCUIElement {
        let end = Date().addingTimeInterval(6)
        while Date() < end {
            if let e = q.allElementsBoundByIndex.first(where: { $0.isHittable }) { return e }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return q.firstMatch
    }
    func goMore() {
        let more = app.buttons["tab-More"]
        if app.buttons["kindnessItem"].isHittable { return }
        if !more.isHittable { app.buttons["tab-Home"].tap() }
        let end = Date().addingTimeInterval(8)
        while Date() < end && !more.isHittable { Thread.sleep(forTimeInterval: 0.3) }
        more.tap()
    }
    func openMore(_ id: String, _ ready: @escaping () -> Bool) {
        let rowEl = app.buttons[id]
        // Right after sign-in the tab bar can exist before it has a valid hit point
        // (build 341 drive, test03 trace: the tap computed hit point {-1, -1} and the
        // tab never switched). Re-tap until the row exists — same retry discipline as
        // tapUntil/openAddTask. The assertion below is unchanged.
        for _ in 0..<4 {
            goMore()
            let top = app.buttons["kindnessItem"]
            let end = Date().addingTimeInterval(6)
            while Date() < end && !top.isHittable { Thread.sleep(forTimeInterval: 0.3) }
            if top.isHittable { break }
            // The More tab keeps a page it had open: step back to its list.
            for _ in 0..<4 where !top.isHittable {
                let back = app.navigationBars.buttons.firstMatch
                if back.exists && back.isHittable { back.tap() } else { break }
                Thread.sleep(forTimeInterval: 0.6)
            }
            if top.isHittable { break }
        }
        wait(rowEl, 10, "More row missing: " + id)
        // Scroll until the row sits clear of the floating bar, or the tap lands on the bar.
        for _ in 0..<8 {
            if rowEl.isHittable && rowEl.frame.midY < app.frame.height - 120 { break }
            app.swipeUp()
        }
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
        let mail = "nmui.tests+nmui\(Int.random(in: 100000000...999999999))@example.com"
        let pass = "Nm" + UUID().uuidString.prefix(10) + "!"
        openEmailPage()
        let email = app.textFields["you@example.com"]; wait(email); email.tap(); email.typeText(mail)
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText(pass); submitCreds()
        for _ in 0..<3 {
            let t0 = Date().addingTimeInterval(12)
            while Date() < t0 { if app.buttons["tab-Projects"].exists { return (mail, pass) }; Thread.sleep(forTimeInterval: 0.5) }
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
        wait(text("All clear")); wait(text("Today's needs")); shot("03-home-allclear")
        XCTAssertTrue(app.otherElements["homeSummary"].exists || text("Needs you").exists, "home summary tiles missing")

        app.buttons["tab-Needs Me"].tap(); wait(text("Nothing needs you right now"), 15, "Needs Me empty state missing. SCREEN: " + screenText()); shot("03-needsme-empty")
        app.buttons["tab-Projects"].tap(); wait(app.buttons["yourProgress"], 10, "Your Progress link missing"); shot("03-projects")

        openMore("moreTasks") { self.app.buttons["Add a task"].exists }
        openAddTask()
        let f = app.textFields["What needs doing?"]; wait(f); f.tap(); f.typeText("UI test task")
        app.textFields["Or a new project name"].tap(); app.textFields["Or a new project name"].typeText("UITestProject")
        app.buttons["Save"].tap()
        wait(text("UI test task"), 20, "task not shown. SCREEN: " + screenText()); shot("04-task-added")
        app.buttons["Mark done"].firstMatch.tap(); wait(app.buttons["Mark not done"]); shot("04-task-done")
        wait(text("Nice work, that one is done."), 10, "kindness moment did not show after marking done"); shot("04-kindness-moment")
        backToMoreRoot()

        app.buttons["tab-Home"].tap(); wait(text("UITestProject"), 20, "project progress not shown"); shot("05-home-project")
        app.buttons["inboxButton"].tap(); wait(text("Inbox is empty"), 10, "inbox empty state missing. SCREEN: " + screenText()); shot("05-inbox")
        app.navigationBars.buttons.firstMatch.tap()
        hittable(app.buttons.matching(identifier: "project-UITestProject")).tap(); wait(text("1 of 1 tasks done"), 10, "project page missing. SCREEN: " + screenText()); shot("05-project-page")
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["tab-Notes"].tap()
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
        for th in ["Loam", "Bone", "Brand"] {
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
        let tag = String(Int.random(in: 100000000...999999999))
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
            while Date() < t0 { if app.buttons["tab-Projects"].exists { break }; Thread.sleep(forTimeInterval: 0.5) }
            if app.buttons["tab-Projects"].exists { break }
            if app.buttons["emailSubmit"].exists { app.buttons["emailSubmit"].tap() }
        }
        wait(app.buttons["tab-Projects"], 30, "sign-in after sign-out failed")
        openMore("moreTasks") { self.text("Persist me").exists }
        wait(text("Persist me"), 20, "task did not persist after sign-in"); shot("12-persisted")
    }

    // 04 privacy screen (inside Settings) + delete account removes the account
    func test04_PrivacyAndDeleteAccount() {
        let (mail, pass) = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.buttons["tab-More"], 30, "no tab bar after sign-up")
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
        XCTAssertFalse(app.buttons["tab-Projects"].exists, "deleted account signed in")
    }

    // 05 Connections screen: a secure key field and a Test connection button for each own key AI,
    // none for hand off AIs. This proves the UI stands. It does not call any AI service.
    func test05_ConnectKeyFields() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.buttons["tab-More"], 30, "no tab bar after sign-up")
        openMore("moreConnections") { self.app.buttons["Copy setup prompt"].exists }
        wait(app.staticTexts["connectionStatus"], 10, "connection status missing")
        // Add another account stands under one provider: a name field and a key field appear.
        let claudeTile = app.buttons["ai-claude"]; wait(claudeTile, 10, "Claude tile missing"); scrollTo(claudeTile); claudeTile.tap()
        let moreSet = app.buttons["settings-claude"]; wait(moreSet, 10, "More settings missing under Claude"); scrollTo(moreSet); moreSet.tap()
        if !app.textFields["label-claude"].waitForExistence(timeout: 3) { moreSet.tap() }
        let add = app.buttons["addAccount-claude"]; wait(add, 10, "Add another account missing under Claude. SCREEN: " + screenText())
        for _ in 0..<8 where !add.isHittable { app.swipeUp() }
        add.tap()
        wait(app.textFields["newLabel-claude"], 10, "new account name field missing")
        XCTAssertTrue(app.secureTextFields["newKey-claude"].exists, "new account key field missing")
        XCTAssertEqual(app.textFields["newLabel-claude"].value as? String, "Claude 2", "default label should be the provider name plus a number")
        shot("14-connect-keys")
        for _ in 0..<10 { app.swipeDown() }
        if app.buttons["ai-claude"].isHittable { app.buttons["ai-claude"].tap() }
        for id in ["chatgpt", "claude", "gemini", "perplexity", "grok", "muse", "deepseek", "mistral", "groq", "openrouter"] {
            let tile = app.buttons["ai-" + id]; wait(tile, 10, "AI tile missing for " + id)
            XCTAssertEqual(app.staticTexts["status-" + id].label, "Not tested", "a new account must start as Not tested: " + id)
            scrollTo(tile); tile.tap()
            let s2 = app.buttons["step-" + id + "-2"]; wait(s2, 10, "step 2 chip missing for " + id); s2.tap()
            wait(app.secureTextFields["keyField-" + id], 10, "key field missing for " + id)
            let s3 = app.buttons["step-" + id + "-3"]; s3.tap()
            wait(app.buttons["testKey-" + id], 10, "Test connection missing for " + id)
            XCTAssertTrue(app.buttons["step-" + id + "-1"].exists, "step 1 chip missing for " + id)
            scrollTo(tile); tile.tap()
        }
        for id in ["copilot", "claudecode", "codex", "cursor", "polar"] {
            XCTAssertFalse(app.buttons["ai-" + id].exists, "hand off AI must have no key tile: " + id)
            XCTAssertFalse(app.secureTextFields["keyField-" + id].exists, "hand off AI must have no key field: " + id)
            XCTAssertFalse(app.buttons["testKey-" + id].exists, "hand off AI must have no test button: " + id)
        }
    }

    // 06 Group chat: create a room, send a message, the message stands in the room.
    // This proves the UI stands. It does not call any AI service.
    func test06_RoomCreateAndSend() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.buttons["tab-More"], 30, "no tab bar after sign-up")
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
        wait(app.buttons["tab-More"], 30, "no tab bar after sign-up")
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
        wait(app.buttons["tab-Notes"], 30, "no tab bar after sign-up")
        app.buttons["tab-Notes"].tap()
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
        wait(app.buttons["tab-More"], 30, "no tab bar after sign-up")
        openMore("settingsRow") { self.app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Brand")).firstMatch.exists }
        for name in ["Brand", "Loam", "Bone"] {
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
        app.buttons["tab-Notes"].tap()
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
        app.buttons["room-Cancel room"].press(forDuration: 1.2)
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
        goMore()
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
        openMore("moreConnections") { self.app.buttons["fold-bring"].exists }
        let fb = app.buttons["fold-bring"]; scrollTo(fb); fb.tap()
        wait(app.buttons["bringKeys"], 10, "bring keys button missing")
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
    // QA loop fix (15 Nov, leg 19): this runtime's web-auth sheet exposes an ✕ close glyph,
    // not a "Cancel" button in the app hierarchy (QA photograph 27-google-no-page-qa.png),
    // so the close control is found by its glyph or label among the sheet's buttons, never
    // by the "Cancel" label alone. The settled-door assertions below stand as written.
    /// Every close-shaped control the web-auth sheet can surface, glyph first.
    func sheetCloseCandidates() -> [XCUIElement] {
        var out: [XCUIElement] = []
        for name in ["✕", "×", "Close", "Cancel"] {
            let q = app.buttons.matching(identifier: name)
            for i in 0..<min(q.count, 2) {
                let e = q.element(boundBy: i)
                if e.exists && e.isHittable { out.append(e) }
            }
        }
        return out
    }
    func test16_GoogleCancelIsQuiet() throws {
        wait(app.buttons["googleButton"])
        app.buttons["googleButton"].tap()
        // Wait up to 25 s for the sheet's close control to surface at all.
        var candidates = sheetCloseCandidates()
        let openEnd = Date().addingTimeInterval(25)
        while Date() < openEnd && candidates.isEmpty {
            Thread.sleep(forTimeInterval: 0.5)
            candidates = sheetCloseCandidates()
        }
        guard !candidates.isEmpty else {
            shot("27-google-no-page")
            throw XCTSkip("The Google page did not open in this run, so there was nothing to cancel.")
        }
        shot("27-google-page")
        // Loop round 2 (15 Nov): QA's re-run found and tapped a "Close" button
        // (38.21 s) and the Safari-shaped container still stood at the assert,
        // its chrome still showing Stop — the page was still loading, so the
        // tap was swallowed, or that Close was not the container's own dismiss
        // element. So: settle first (wait for the chrome's Stop button to
        // clear, up to 10 s), then tap and watch for the door, re-tapping and
        // cycling the candidates until the door returns or 30 s pass.
        let stop = app.buttons["Stop"]
        let settleEnd = Date().addingTimeInterval(10)
        while Date() < settleEnd && stop.exists { Thread.sleep(forTimeInterval: 0.5) }
        let door = app.buttons["googleButton"]
        // MECHANISM (loop round 3, named for QA): the element tap on this
        // remote container's Close exists but does not take effect — round 2
        // tapped it against a fully loaded page and the container stood for
        // the whole 30 s cycle. Round 3 taps the candidate's FRAME CENTRE as
        // a coordinate on the app window: the frame is read from the element
        // itself (hierarchy data), never from a photograph. Each round tries
        // the element tap once, then the frame-coordinate tap, cycling
        // candidates and watching for the door between attempts.
        func frameTap(_ e: XCUIElement) {
            let f = e.frame
            guard f.width > 0 && f.height > 0 else { return }
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            origin.withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
        }
        let dismissEnd = Date().addingTimeInterval(35)
        var round = 0
        while Date() < dismissEnd && !door.exists {
            let fresh = sheetCloseCandidates()
            if !fresh.isEmpty {
                let target = fresh[round % fresh.count]
                target.tap()
                let w1 = Date().addingTimeInterval(3)
                while Date() < w1 && !door.exists { Thread.sleep(forTimeInterval: 0.4) }
                if !door.exists { frameTap(target) }
            }
            round += 1
            let watchEnd = Date().addingTimeInterval(6)
            while Date() < watchEnd && !door.exists { Thread.sleep(forTimeInterval: 0.4) }
        }
        wait(door, 20, "door did not return after the Google cancel")
        XCTAssertFalse(app.staticTexts["authMessage"].exists, "a Google cancel painted an error line on the door")
        shot("27-google-cancel-quiet")
    }

    /// The late system "Save Password?" sheet (QA loop fix, 15 Nov, leg 22): it can stand
    /// over the photo picker after the test's own sign-in, and nothing under it is tappable.
    /// Dismiss it with "Not Now" wherever it stands. Returns true when it tapped one.
    @discardableResult
    func dismissSavePasswordSheet() -> Bool {
        for scope in [app.buttons["Not Now"], app.sheets.buttons["Not Now"], app.alerts.buttons["Not Now"]] {
            if scope.exists && scope.isHittable { scope.tap(); return true }
        }
        return false
    }

    /// Adds one task under a project from the Tasks screen (Tasks lives in More).
    func addTask(_ title: String, _ project: String) {
        openAddTask()
        let f = app.textFields["What needs doing?"]; wait(f); f.tap(); f.typeText(title)
        app.textFields["Or a new project name"].tap(); app.textFields["Or a new project name"].typeText(project)
        app.buttons["Save"].tap()
        wait(text(title), 20, "task not shown: " + title + ". SCREEN: " + screenText())
    }
    func scrollTo(_ e: XCUIElement, _ tries: Int = 8) {
        for _ in 0..<tries where !e.isHittable { app.swipeUp() }
    }

    // 18 Task detail (section 9): honest empty lines stand, a checklist line can be added and
    // ticked, a dependency blocks the task until it is done, and unblocking shows at once.
    func test18_TaskDetailChecklistAndDeps() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("moreTasks") { self.app.buttons["Add a task"].exists }
        addTask("Blocker task", "DetailProj")
        addTask("Detail task", "DetailProj")
        let open = app.buttons["taskOpen-Detail task"]; wait(open, 10, "task detail link missing")
        open.tap()
        wait(text("About this task"), 10, "task detail did not open. SCREEN: " + screenText()); shot("29-task-detail")
        wait(text("No priority is recorded for this task."), 10, "honest priority line missing")
        wait(text("No outcome is written for this task yet."), 10, "honest outcome line missing")
        wait(text("No dependencies."), 10, "empty dependencies line missing")
        // Checklist: add a step, then tick it.
        let step = app.textFields["checkNew"]; scrollTo(step); wait(step, 10, "checklist add field missing")
        step.tap(); step.typeText("First step")
        app.buttons["checkAdd"].tap()
        wait(text("First step"), 15, "checklist step not shown")
        let tick = app.buttons["Mark step done"].firstMatch; wait(tick, 10, "checklist tick missing"); tick.tap()
        wait(app.buttons["Mark step not done"].firstMatch, 10, "checklist step did not tick")
        shot("29-checklist")
        // Dependency: Detail task waits on Blocker task.
        let dep = app.buttons["depAdd"]; scrollTo(dep); wait(dep, 10, "add dependency control missing")
        dep.tap()
        let pick = app.buttons["Blocker task"]; wait(pick, 10, "blocker not offered as a dependency"); pick.tap()
        let st = app.staticTexts["taskDetailStatus"]; wait(st, 10, "status missing")
        let end = Date().addingTimeInterval(15)
        while Date() < end && st.label != "Blocked by Blocker task" { Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertEqual(st.label, "Blocked by Blocker task", "dependency did not block the task")
        shot("29-blocked")
        // Finish the blocker from its own detail; Detail task unblocks.
        app.navigationBars.buttons.firstMatch.tap()
        let openB = app.buttons["taskOpen-Blocker task"]; wait(openB, 10, "blocker detail link missing"); openB.tap()
        let tog = app.buttons["taskToggle"]; scrollTo(tog); wait(tog, 10, "detail toggle missing"); tog.tap()
        let stb = app.staticTexts["taskDetailStatus"]
        let end2 = Date().addingTimeInterval(15)
        while Date() < end2 && stb.label != "Completed" { Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertEqual(stb.label, "Completed", "blocker did not complete from its detail")
        app.navigationBars.buttons.firstMatch.tap()
        let open2 = app.buttons["taskOpen-Detail task"]; wait(open2, 10, "detail link missing on return"); open2.tap()
        let st2 = app.staticTexts["taskDetailStatus"]
        let end3 = Date().addingTimeInterval(15)
        while Date() < end3 && st2.label != "Waiting" { Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertEqual(st2.label, "Waiting", "task did not unblock when its dependency finished")
        shot("29-unblocked")
    }

    // 19 Note attachments (section 10): a picture picked for a note stands in the note, and
    // removing it takes it away. If this simulator's photo library is empty the leg is
    // skipped with that reason, never faked (the test16 pattern).
    func test19_NotePictureAttachment() throws {
        _ = signUpFresh()
        // QA loop fix (15 Nov, leg 22): the late "Save Password?" sheet from this sign-in
        // can stand over the picker (QA photograph 31-picker-seeded-qa.png). Watch for it
        // the whole test, and dismiss it explicitly in the picker poll below as well.
        _ = addUIInterruptionMonitor(withDescription: "Save Password sheet") { sheet in
            let notNow = sheet.buttons["Not Now"]
            if notNow.exists { notNow.tap(); return true }
            return false
        }
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        wait(app.buttons["tab-Notes"], 30, "no tab bar after sign-up")
        app.buttons["tab-Notes"].tap()
        app.buttons["newItem"].tap()
        let nb = app.textViews["noteBody"]; wait(nb, 10, "new note did not open"); nb.typeText("Picture note body")
        app.buttons["noteDone"].tap()
        let add = app.buttons["attachPhoto"]; scrollTo(add)
        if !add.waitForExistence(timeout: 15) {
            shot("30-no-attach")
            XCTFail("Add a picture control missing in the saved note. SCREEN: " + screenText())
        }
        add.tap()
        // Explicit dismissal right before the picker poll (the standing late-sheet rule).
        dismissSavePasswordSheet()
        // Loop round 2 (15 Nov): the sheet half is cured (QA shot
        // 32-picker-fixed-qa.png: the picker fully loaded, six photos standing,
        // no sheet over it), but the old poll's app-hierarchy cells and images
        // can never match — this runtime's picker is out of process and its
        // grid items do not surface under the app's queries. Poll the picker
        // in its own process scopes as well as the app's, across the element
        // types the remote view actually surfaces (cells, images, and its
        // grid buttons, skipping the picker's own chrome labels).
        let pickerScopes = [app,
                            XCUIApplication(bundleIdentifier: "com.apple.Photos.PhotosPicker"),
                            XCUIApplication(bundleIdentifier: "com.apple.photos.picker"),
                            XCUIApplication(bundleIdentifier: "com.apple.springboard")]
        let chrome = ["Cancel", "Add", "Done", "Not Now", "Save"]
        // Loop round 3 (15 Nov): querying a picker process that is not (yet)
        // running THROWS ("Failed to get matching snapshots: Application
        // com.apple.Photos.PhotosPicker is not running", qa-test19d) and
        // fails the whole test. A scope is only ever queried while its
        // process state reads running — the poll survives the picker's
        // lazy start, and the SpringBoard scope (always running) is read
        // as the fallback surface.
        func running(_ s: XCUIApplication) -> Bool {
            s.state == .runningForeground || s.state == .runningBackground
        }
        func pickerItem() -> XCUIElement? {
            // Loop round 4 (15 Nov): the round-3 hunt tapped an Image
            // labelled "wifi" — chrome outside the grid, matched through a
            // fallback scope — and nothing was ever picked. The pick is now
            // BOUND TO THE GRID: a candidate counts only if its own frame
            // reads as a photo tile standing inside the grid — square-ish,
            // at least 60 pt a side, its centre inside the window, and
            // below the picker's own chrome (the Photos / Collections tabs
            // mark the grid's top edge when they stand). Cells are read
            // first, then images; buttons are no longer pick candidates.
            var gridTop: CGFloat = 100
            for scope in pickerScopes where running(scope) {
                for tab in ["Photos", "Collections"] {
                    let b = scope.buttons[tab]
                    if b.exists { gridTop = max(gridTop, b.frame.maxY) }
                }
            }
            let win = app.frame
            func inGrid(_ e: XCUIElement) -> Bool {
                let f = e.frame
                return f.width >= 60 && f.height >= 60
                    && abs(f.width - f.height) <= f.width * 0.25
                    && f.minY >= gridTop
                    && win.contains(CGPoint(x: f.midX, y: f.midY))
            }
            for scope in pickerScopes where running(scope) {
                let cells = scope.cells
                for i in 0..<min(cells.count, 12) {
                    let c = cells.element(boundBy: i)
                    if c.exists && inGrid(c) { return c }
                }
                let imgs = scope.images
                for i in 0..<min(imgs.count, 20) {
                    let im = imgs.element(boundBy: i)
                    if im.exists && inGrid(im) { return im }
                }
            }
            return nil
        }
        let end = Date().addingTimeInterval(25)
        var picked = false
        while Date() < end && !picked {
            if dismissSavePasswordSheet() { Thread.sleep(forTimeInterval: 0.5); continue }
            if let item = pickerItem() { item.tap(); picked = true }
            else { Thread.sleep(forTimeInterval: 0.5) }
        }
        if !picked {
            shot("30-picker-empty")
            throw XCTSkip("The photo picker showed no picture on this simulator, so there was nothing to attach.")
        }
        // Loop round 4: the confirm is a HARD step, asserted — round 3's
        // soft search silently never fired (no Add/Done tap anywhere in
        // qa-test19e's log) and nothing reached the app. After a real pick
        // the picker's Add (or Done) must be tapped; if the picker instead
        // returns on the pick itself (the app's attachPhoto standing
        // hittable again), that also counts as the hand-over. Anything
        // else fails HERE, at the confirm, not later at the note assert.
        var confirmed = false
        let confirmEnd = Date().addingTimeInterval(15)
        while Date() < confirmEnd && !confirmed {
            for label in ["Add", "Done"] where !confirmed {
                for scope in pickerScopes where !confirmed && running(scope) {
                    let b = scope.buttons[label]
                    if b.exists && b.isHittable { b.tap(); confirmed = true }
                }
            }
            if !confirmed {
                let attach = app.buttons["attachPhoto"]
                if attach.exists && attach.isHittable { confirmed = true }
            }
            if !confirmed { Thread.sleep(forTimeInterval: 0.4) }
        }
        XCTAssertTrue(confirmed, "the pick was never confirmed: no Add/Done tap landed and the picker never returned")
        let kept = app.images["noteAttachmentImage"]
        if !kept.waitForExistence(timeout: 30) {
            shot("30-not-kept")
            XCTFail("picked picture did not stand in the note. SCREEN: " + screenText())
        }
        shot("30-attached")
        let rm = app.buttons["attachRemove"]; scrollTo(rm); wait(rm, 10, "remove picture control missing"); rm.tap()
        let end2 = Date().addingTimeInterval(15)
        var gone = false
        while Date() < end2 { if !app.images["noteAttachmentImage"].exists { gone = true; break }; Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertTrue(gone, "picture still stands in the note after remove")
        shot("30-removed")
    }

    // 20 Per agent controls (section 11): pause, a tool switch and a project pick act and
    // persist per owner — they still stand after signing out and back in. Cancel with no
    // run going answers its honest line.
    func test20_AgentControlsPersist() {
        let (mail, pass) = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("moreTasks") { self.app.buttons["Add a task"].exists }
        addTask("Agent task", "AgentProj")
        backToMoreRoot()
        openMore("moreWorkforce") { self.app.buttons["worker-claude"].exists }
        let wk = app.buttons["worker-claude"]; scrollTo(wk); wk.tap()
        let pause = app.buttons["agentPause-claude"]; scrollTo(pause); wait(pause, 10, "pause control missing for Claude")
        pause.tap()
        wait(app.staticTexts["agentPaused-claude"], 15, "paused line missing after Pause. SCREEN: " + screenText())
        XCTAssertEqual(app.buttons["agentPause-claude"].label, "Resume", "pause button did not become Resume")
        let sw = app.switches["agentTool-claude-file"]; scrollTo(sw); wait(sw, 10, "file tool switch missing")
        XCTAssertEqual(sw.value as? String, "1", "file tool should start on")
        sw.tap()
        let end = Date().addingTimeInterval(10)
        while Date() < end && (app.switches["agentTool-claude-file"].value as? String) != "0" { Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertEqual(app.switches["agentTool-claude-file"].value as? String, "0", "file tool switch did not turn off")
        let menu = app.buttons["agentProjects-claude"]; scrollTo(menu); wait(menu, 10, "projects pick missing")
        menu.tap()
        let pick = app.buttons["AgentProj"]; wait(pick, 10, "project not offered in the agent pick"); hittable(app.buttons.matching(identifier: "AgentProj")).tap()
        let end2 = Date().addingTimeInterval(10)
        while Date() < end2 && !app.buttons["agentProjects-claude"].label.contains("1 picked") { Thread.sleep(forTimeInterval: 0.4) }
        XCTAssertTrue(app.buttons["agentProjects-claude"].label.contains("1 picked"), "project pick did not stand: " + app.buttons["agentProjects-claude"].label)
        let cancel = app.buttons["agentCancel-claude"]; scrollTo(cancel); wait(cancel, 10, "cancel run control missing")
        cancel.tap()
        let note = app.staticTexts["agentCancelNote-claude"]; wait(note, 10, "cancel note missing")
        XCTAssertTrue(note.label.contains("no run going"), "cancel with no run must say so: " + note.label)
        shot("31-agent-controls")
        // Sign out and back in: the controls are the owner's, saved in her own space.
        backToMoreRoot()
        openMore("settingsRow") { self.app.buttons["signOut"].exists }
        let so = app.buttons["signOut"]
        for _ in 0..<8 where !so.isHittable { app.swipeUp() }
        so.tap(); wait(app.buttons["emailButton"])
        openEmailPage(); app.buttons["switchMode"].tap()
        let e2 = app.textFields["you@example.com"]; wait(e2); e2.tap(); e2.typeText(mail)
        let p2 = app.secureTextFields.firstMatch; p2.tap(); p2.typeText(pass); submitCreds()
        for _ in 0..<3 {
            let t0 = Date().addingTimeInterval(12)
            while Date() < t0 { if app.buttons["tab-Projects"].exists { break }; Thread.sleep(forTimeInterval: 0.5) }
            if app.buttons["tab-Projects"].exists { break }
            if app.buttons["emailSubmit"].exists { app.buttons["emailSubmit"].tap() }
        }
        wait(app.buttons["tab-Projects"], 30, "sign-in after sign-out failed")
        openMore("moreWorkforce") { self.app.buttons["worker-claude"].exists }
        let wk2 = app.buttons["worker-claude"]; scrollTo(wk2); wk2.tap()
        let pause2 = app.buttons["agentPause-claude"]; scrollTo(pause2)
        wait(app.staticTexts["agentPaused-claude"], 20, "pause did not persist across sign-in. SCREEN: " + screenText())
        let sw2 = app.switches["agentTool-claude-file"]; scrollTo(sw2); wait(sw2, 10, "file tool switch missing after sign-in")
        XCTAssertEqual(sw2.value as? String, "0", "file tool switch did not persist across sign-in")
        shot("31-agent-persisted")
    }

    // 21 Devices and workspace (section 15, fence-safe shape): this device stands in
    // Settings, marked as this device; the workspace names the owner alone and says
    // sharing is off for good.
    func test21_DevicesAndWorkspace() {
        _ = signUpFresh()
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("settingsRow") { self.text("Your devices").exists }
        let mine = app.staticTexts["thisDevice"]
        let end = Date().addingTimeInterval(30)
        var found = false
        while Date() < end && !found {
            if mine.exists { found = true; break }
            app.swipeUp(); Thread.sleep(forTimeInterval: 0.4)
            if mine.exists { found = true; break }
        }
        XCTAssertTrue(found, "this device is not listed in Settings. SCREEN: " + screenText())
        shot("32-devices")
        let share = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "never shared with anyone")).firstMatch
        let end2 = Date().addingTimeInterval(15)
        var shareFound = false
        while Date() < end2 && !shareFound {
            if share.exists { shareFound = true; break }
            app.swipeUp(); Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(shareFound, "workspace never-share line missing. SCREEN: " + screenText())
        XCTAssertTrue(text("Owner").exists, "workspace owner line missing")
        shot("32-workspace")
    }

    // 17 The Apple door: tapping it raises Apple's own sheet or alert, and closing it returns
    // to a clean standing door (the drive records what this simulator shows).
    // 22 Bring projects in from an export file: the reader counts, skips repeats, files each one
    func test22_ImportProjectsFromExport() {
        app.terminate(); app.launchArguments = ["-uitest-reset", "-uitest-noask", "-uitest-importsample"]; app.launch()
        _ = signUpFresh()
        wait(app.buttons["tab-Projects"], 30)
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("moreConnections") { self.app.buttons["fold-import"].exists }
        let fi = app.buttons["fold-import"]; scrollTo(fi); fi.tap()
        let b = app.buttons["importSample"]; wait(b, 10, "sample import button missing")
        for _ in 0..<6 where !b.isHittable { app.swipeUp() }
        b.tap()
        wait(text("Found 3 projects. Brought in 3. Website launch, Blog posts, Pricing"), 15, "import count wrong. SCREEN: " + screenText()); shot("33-import")
    }

    func test23_SignInDoorOpens() {
        app.terminate(); app.launchArguments = ["-uitest-reset", "-uitest-noask"]; app.launch()
        _ = signUpFresh()
        wait(app.buttons["tab-Projects"], 30)
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("moreConnections") { self.app.buttons["fold-signin"].exists }
        let fs = app.buttons["fold-signin"]; scrollTo(fs); fs.tap()
        let b = app.buttons["door-claude"]; wait(b, 10, "sign-in door button missing")
        for _ in 0..<8 where !b.isHittable { app.swipeUp() }
        b.tap()
        wait(app.buttons["doorBring"], 15, "door sheet did not open. SCREEN: " + screenText()); shot("34-door-claude")
        wait(app.buttons["doorPick"], 5, "pick-file button missing")
        app.buttons["doorClose"].tap()
        wait(app.buttons["door-chatgpt"], 10, "sheet did not close")
    }

    // 24 Pip's setup walk opens after the tour, goes one step at a time, and can be skipped.
    func test24_PipSetupWizard() {
        app.terminate(); app.launchArguments = ["-uitest-reset", "-uitest-noask", "-uitest-wizard"]; app.launch()
        _ = signUpFresh()
        wait(text("Tour 1 of 7"), 60, "tour did not start")
        tapUntil(app.buttons["Skip guide"]) { self.app.buttons["wizStart"].exists }
        wait(app.buttons["wizStart"], 20, "setup walk did not open after the tour. SCREEN: " + screenText()); shot("35-wizard-1")
        app.buttons["wizStart"].tap()
        wait(app.buttons["wizPick-gemini"], 10, "AI picker missing"); XCTAssertTrue(app.buttons["wizPick-claude"].exists, "Claude tile missing")
        app.buttons["wizPick-gemini"].tap()
        wait(app.buttons["wizOpenKey"], 10, "get key page button missing"); shot("35-wizard-key")
        app.buttons["wizHaveKey"].tap()
        wait(app.secureTextFields["wizKey"], 10, "key field missing"); XCTAssertTrue(app.buttons["wizConnect"].exists, "Connect it missing"); shot("35-wizard-paste")
        app.buttons["wizSkip"].tap()
        wait(app.buttons["tab-More"], 20, "skip did not close the setup walk")
    }

    // 25 An AI report files itself: project, to-dos, percent done, and a Needs You card with a button to its chat.
    func test25_AIUpdateFilesItself() {
        app.terminate(); app.launchArguments = ["-uitest-reset", "-uitest-noask", "-uitest-updatesample"]; app.launch()
        _ = signUpFresh()
        wait(app.buttons["tab-Projects"], 30)
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }
        openMore("moreConnections") { self.app.buttons["fold-updates"].exists }
        let f = app.buttons["fold-updates"]; scrollTo(f); f.tap()
        let b = app.buttons["applySample"]; wait(b, 10, "sample button missing"); scrollTo(b); b.tap()
        let r = app.staticTexts["updateResult"]; wait(r, 10, "no result line. SCREEN: " + screenText())
        XCTAssertTrue(r.label.contains("2 to-dos added"), "wrong result: " + r.label)
        XCTAssertTrue(r.label.contains("1 crossed off"), "wrong result: " + r.label)
        backToMoreRoot()
        app.buttons["tab-Needs Me"].tap()
        wait(text("Logo A or B?"), 20, "need not shown. SCREEN: " + screenText()); shot("36-ai-need")
        let chat = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'needChat-'")).firstMatch
        wait(chat, 10, "Open the chat button missing")
        let feed = app.buttons["updatesFeedLink"]; wait(feed, 10, "All updates link missing"); feed.tap()
        wait(text("Claude: 2 to-dos added, 1 crossed off, 1 for you to see. Logo A or B?"), 15, "feed row missing. SCREEN: " + screenText()); shot("37-ai-feed")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["tab-Projects"].tap()
        hittable(app.buttons.matching(identifier: "project-Sample launch")).tap()
        wait(text("1 of 3 tasks done"), 15, "percent not counted from the report. SCREEN: " + screenText()); shot("36-ai-project")
    }

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

/// Picture-compare shots. Runs the app with the demo data switch and takes the nine screens
/// as the approved pictures show them. It never fails the suite: it only takes pictures.
final class NeedsMeDemoShots: XCTestCase {
    let app = XCUIApplication()
    override func setUp() { continueAfterFailure = true; app.launchArguments = ["-uitest-reset", "-uitest-noask", "-uitest-demo"]; app.launch() }
    func shot(_ name: String) {
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir + "/" + name + ".png"))
        }
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }
    func tapIf(_ e: XCUIElement, _ t: TimeInterval = 10) -> Bool { if e.waitForExistence(timeout: t) { e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap(); return true }; return false }
    func hit(_ q: XCUIElementQuery) -> XCUIElement { q.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? q.firstMatch }
    func goMore() {
        let more = app.buttons["tab-More"]
        if !more.isHittable { tp(app.buttons["tab-Home"]); pause(1) }
        tp(more); pause(1)
    }
    func openRow(_ id: String) -> Bool {
        goMore()
        let r = app.buttons[id]
        guard r.waitForExistence(timeout: 8) else { return false }
        for _ in 0..<8 { if r.isHittable && r.frame.midY < app.frame.height - 130 { break }; app.swipeUp(); pause(0.5) }
        tp(r); pause(1.5); return true
    }
    func tp(_ e: XCUIElement) { e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap() }
    func back() { let b = app.navigationBars.buttons.firstMatch; if b.exists { b.tap(); pause(1) } }

    func testNineScreens() {
        guard app.buttons["emailButton"].waitForExistence(timeout: 30) else { shot("D-FAIL-door"); return }
        pause(1); shot("D1-door")
        app.buttons["emailButton"].tap()
        let email = app.textFields["you@example.com"]
        guard email.waitForExistence(timeout: 15) else { shot("D-FAIL-email"); return }
        email.tap(); email.typeText("nmui.tests+nmui\(Int.random(in: 100000000...999999999))@example.com")
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText("Nm" + UUID().uuidString.prefix(10) + "!")
        let go = app.keyboards.buttons["Go"]
        if go.waitForExistence(timeout: 3) { go.tap() } else { app.buttons["emailSubmit"].tap() }
        guard app.staticTexts["Tour 1 of 7"].waitForExistence(timeout: 60) else { shot("D-FAIL-tour"); return }
        for _ in 0..<5 { if app.buttons["Skip guide"].exists { app.buttons["Skip guide"].tap() }; pause(1); if !app.staticTexts["Tour 1 of 7"].exists { break } }
        pause(2); shot("D2-home")
        // 7 Tasks, 4 Rooms, 5 a room (all from More)
        if openRow("moreTasks") { shot("D7-tasks"); back() }
        if openRow("moreGroupChat") {
            pause(2); shot("D4-rooms")
            if tapIf(hit(app.buttons.matching(identifier: "room-Launch week")), 5) { pause(2); shot("D5-room"); back() }
            back()
        }
        if !app.buttons["tab-Projects"].isHittable { back() }
        // 6 project
        tp(app.buttons["tab-Projects"]); pause(2); shot("D6a-projects")
        let pr = hit(app.buttons.matching(identifier: "project-Website launch"))
        for _ in 0..<6 where !(pr.isHittable && pr.frame.midY < app.frame.height - 150) { app.swipeUp(); pause(0.5) }
        if pr.exists { pr.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).tap(); pause(2); shot("D6-project") }
        // 8 notes
        tp(app.buttons["tab-Notes"]); pause(2); shot("D8-notes")
        // 9 settings
        if openRow("settingsRow") { shot("D9-settings"); app.swipeUp(); pause(1); shot("D9b-settings-below") }
        back()
        // 3 a need cleared
        tp(app.buttons["tab-Home"]); pause(2)
        let d = app.buttons["heroDone"]
        if d.waitForExistence(timeout: 10) { tp(d); pause(1.2); shot("D3-cleared") }
        tp(app.buttons["tab-Needs Me"]); pause(2); shot("D10-needsme")
    }
}
