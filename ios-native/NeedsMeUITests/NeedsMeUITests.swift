import XCTest

final class NeedsMeUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUp() { continueAfterFailure = false; app.launchArguments = ["-uitest-reset"]; app.launch() }

    func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir + "/" + name + ".png"))
        }
    }
    func wait(_ e: XCUIElement, _ t: TimeInterval = 20, _ m: String = "") {
        if !e.waitForExistence(timeout: t) {
            shot("FAIL-" + String(Int.random(in: 100...999)))
            let btns = app.buttons.allElementsBoundByIndex.prefix(14).map { $0.label }.joined(separator: ",")
            XCTFail((m.isEmpty ? "missing \(e)" : m) + " | BUTTONS: " + btns + " | TEXTS: " + screenText())
        }
    }
    func screenText() -> String { app.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ").suffix(260).description }
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
    func openAddTask() {
        for _ in 0..<4 {
            wait(app.buttons["Add a task"]); app.buttons["Add a task"].tap()
            if app.textFields["What needs doing?"].waitForExistence(timeout: 6) { return }
        }
    }
    func signUpFresh() -> (String, String) {
        let mail = "projects.reports.ilse+nmui\(Int.random(in: 1000...9999))@gmail.com"
        let pass = "Nm" + UUID().uuidString.prefix(10) + "!"
        wait(app.buttons["emailButton"]); app.buttons["emailButton"].tap()
        let email = app.textFields["you@example.com"]; wait(email); email.tap(); email.typeText(mail)
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText(pass); submitCreds()
        for _ in 0..<3 {
            let t0 = Date().addingTimeInterval(12)
            while Date() < t0 { if app.tabBars.buttons["Tasks"].exists { return (mail, pass) }; Thread.sleep(forTimeInterval: 0.5) }
            if app.buttons["emailSubmit"].exists && app.staticTexts["authMessage"].exists == false { app.buttons["emailSubmit"].tap() }
        }
        return (mail, pass)
    }
    func text(_ s: String) -> XCUIElement { app.staticTexts[s] }

    // 01 first screen is sign up with Apple, Google, email; Google door is honest; bad login shows error
    func test01_SignUpFirstAndInvalidLogin() {
        wait(app.buttons["emailButton"]); shot("01-signup-first")
        XCTAssertTrue(app.staticTexts["Welcome to NeedsMe Ai"].exists, "sign up is not the first screen")
        XCTAssertTrue(app.buttons["appleButton"].exists, "Apple button missing")
        XCTAssertTrue(app.buttons["googleButton"].exists, "Google button missing")
        XCTAssertTrue(app.buttons["emailButton"].exists, "Email button missing")
        shot("01-google-door")
        app.buttons["switchMode"].tap(); wait(app.staticTexts["Welcome back"])
        app.buttons["emailButton"].tap()
        let email = app.textFields["you@example.com"]; wait(email); email.tap(); email.typeText("projects.reports.ilse+nmui0000@gmail.com")
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText("wrong-pass-123"); submitCreds()
        if !app.staticTexts["authMessage"].waitForExistence(timeout: 15) { app.buttons["emailSubmit"].tap() }
        wait(app.staticTexts["authMessage"], 40, "no error for invalid login"); shot("01-invalid-login")
    }

    // 02 guest -> Pip tour (Next/Back/Finish) -> Home -> Tasks -> Notes -> themes -> replay -> sign out
    func test02_FullJourney() {
        _ = signUpFresh()
        wait(text("Tour 1 of 7"), 60, "tour did not start after sign-up. SCREEN: " + screenText()); shot("02-tour-1")
        tapUntil(app.buttons["Next"]) { self.text("Tour 2 of 7").exists }; wait(text("Tour 2 of 7")); shot("02-tour-2")
        tapUntil(app.buttons["Back"]) { self.text("Tour 1 of 7").exists }; wait(text("Tour 1 of 7"))
        for n in 2...7 { tapUntil(app.buttons["Next"]) { self.text("Tour \(n) of 7").exists }; wait(text("Tour \(n) of 7")) }
        shot("02-tour-7"); tapUntil(app.buttons["Finish tour"]) { !self.app.buttons["Finish tour"].exists }
        wait(text("All clear")); wait(text("Needs your attention")); wait(text("Continue where you left off")); wait(text("Recent activity")); shot("03-home-allclear")

        tapUntil(app.tabBars.buttons["Tasks"]) { self.app.buttons["Add a task"].exists }
        openAddTask()
        let f = app.textFields["What needs doing?"]; wait(f); f.tap(); f.typeText("UI test task")
        app.textFields["Or a new project name"].tap(); app.textFields["Or a new project name"].typeText("UITestProject")
        app.buttons["Save"].tap()
        wait(text("UI test task"), 20, "task not shown. SCREEN: " + screenText()); shot("04-task-added")
        app.buttons["Mark done"].firstMatch.tap(); wait(app.buttons["Mark not done"]); shot("04-task-done")

        app.tabBars.buttons["Home"].tap(); wait(text("UITestProject"), 20, "project progress not shown"); shot("05-home-project")
        app.buttons["inboxButton"].tap(); wait(text("Inbox is empty"), 10, "inbox empty state missing. SCREEN: " + screenText()); shot("05-inbox")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["project-UITestProject"].tap(); wait(text("1 of 1 tasks done"), 10, "project page missing. SCREEN: " + screenText()); shot("05-project-page")
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Notes"].tap()
        app.buttons["New"].tap()
        let t = app.textFields["Title"]; wait(t); t.tap(); t.typeText("UI test note about UITestProject")
        wait(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Looks like this belongs in UITestProject'")).firstMatch, 10, "project suggestion missing")
        shot("06-note-suggestion")
        app.buttons["Save"].tap(); wait(text("UI test note about UITestProject")); shot("06-note-saved")
        app.segmentedControls.buttons["Prompts"].tap(); wait(text("No prompts yet. Tap + to save one.")); shot("06-prompts-empty")

        app.tabBars.buttons["AI"].tap(); wait(app.buttons["Copy setup prompt"], 10, "setup prompt button missing"); shot("07-connect")

        app.tabBars.buttons["More"].tap()
        let mp = app.segmentedControls["motionPicker"]; wait(mp, 10, "motion setting missing")
        mp.buttons["Reduced"].tap(); XCTAssertTrue(mp.buttons["Reduced"].isSelected, "Reduced motion did not select"); shot("08-motion-reduced")
        mp.buttons["System"].tap()
        let dg = app.segmentedControls["digestPicker"]; wait(dg, 10, "digest setting missing")
        dg.buttons["Weekly"].tap(); XCTAssertTrue(dg.buttons["Weekly"].isSelected, "Weekly digest did not select"); shot("08-alerts")
        for th in ["Dark", "Soft Green", "Soft White"] {
            let b = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", th)).firstMatch; wait(b); b.tap(); shot("08-theme-" + th)
        }
        app.buttons["Replay Pip's guide"].tap(); wait(text("Tour 1 of 7")); shot("09-replay")
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }; XCTAssertFalse(text("Tour 1 of 7").exists)
        app.buttons["Sign out"].tap(); wait(app.buttons["emailButton"]); shot("10-signed-out")
    }

    // 03 real email sign-up with random test account, skip tour, data persists across sign-out/in
    func test03_EmailSignUpSignInRoundTrip() {
        let tag = String(Int.random(in: 1000...9999))
        let mail = "projects.reports.ilse+nmui\(tag)@gmail.com"
        let pass = "Nm" + UUID().uuidString.prefix(10) + "!"
        wait(app.buttons["emailButton"])
        app.buttons["emailButton"].tap()
        let email = app.textFields["you@example.com"]; email.tap(); email.typeText(mail)
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText(pass)
        app.buttons["emailSubmit"].tap()
        wait(text("Tour 1 of 7"), 30, "sign-up did not reach tour. SCREEN: " + screenText()); shot("11-signup-tour")
        tapUntil(app.buttons["Skip guide"]) { !self.app.buttons["Skip guide"].exists }; wait(text("All clear"))
        tapUntil(app.tabBars.buttons["Tasks"]) { self.app.buttons["Add a task"].exists }; openAddTask()
        let f = app.textFields["What needs doing?"]; wait(f, 20, "add-task sheet missing. SCREEN: " + screenText()); f.tap(); f.typeText("Persist me"); app.buttons["Save"].tap(); wait(text("Persist me"))
        app.tabBars.buttons["More"].tap(); app.buttons["Sign out"].tap()
        wait(app.buttons["emailButton"])
        app.buttons["switchMode"].tap(); app.buttons["emailButton"].tap()
        let e2 = app.textFields["you@example.com"]; wait(e2); e2.tap(); e2.typeText(mail)
        let p2 = app.secureTextFields.firstMatch; p2.tap(); p2.typeText(pass); submitCreds()
        for _ in 0..<3 {
            let t0 = Date().addingTimeInterval(12)
            while Date() < t0 { if app.tabBars.buttons["Tasks"].exists { break }; Thread.sleep(forTimeInterval: 0.5) }
            if app.tabBars.buttons["Tasks"].exists { break }
            if app.buttons["emailSubmit"].exists { app.buttons["emailSubmit"].tap() }
        }
        wait(app.tabBars.buttons["Tasks"], 30, "sign-in after sign-out failed"); app.tabBars.buttons["Tasks"].tap()
        wait(text("Persist me"), 20, "task did not persist after sign-in"); shot("12-persisted")
    }
}
