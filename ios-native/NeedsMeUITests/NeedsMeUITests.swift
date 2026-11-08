import XCTest

final class NeedsMeUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUp() { continueAfterFailure = false; app.launch() }

    func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir + "/" + name + ".png"))
        }
    }
    func wait(_ e: XCUIElement, _ t: TimeInterval = 20, _ m: String = "") { XCTAssertTrue(e.waitForExistence(timeout: t), m.isEmpty ? "missing \(e)" : m) }
    func screenText() -> String { app.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ") }
    func text(_ s: String) -> XCUIElement { app.staticTexts[s] }

    // 01 sign-in screen shows, bad password gives an error, no crash
    func test01_InvalidLoginShowsError() {
        wait(app.buttons["guestButton"]); shot("01-auth")
        let email = app.textFields["you@example.com"]; email.tap(); email.typeText("projects.reports.ilse+nmui0000@gmail.com")
        let pw = app.secureTextFields["Password"]; pw.tap(); pw.typeText("wrong-pass-123")
        app.buttons["Sign in"].tap()
        let err = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'password' OR label CONTAINS[c] 'credential' OR label CONTAINS[c] 'incorrect' OR label CONTAINS[c] 'no user' OR label CONTAINS[c] 'malformed'")).firstMatch
        wait(err, 25, "no error message for invalid login"); shot("01-invalid-login")
    }

    // 02 guest -> Pip tour (Next/Back/Finish) -> Home -> Tasks -> Notes -> themes -> replay -> sign out
    func test02_GuestFullJourney() {
        wait(app.buttons["guestButton"]); app.buttons["guestButton"].tap()
        wait(text("Tour 1 of 7"), 60, "tour did not start after sign-up. SCREEN: " + screenText()); shot("02-tour-1")
        app.buttons["Next"].tap(); wait(text("Tour 2 of 7")); shot("02-tour-2")
        app.buttons["Back"].tap(); wait(text("Tour 1 of 7"))
        for n in 2...7 { app.buttons["Next"].tap(); wait(text("Tour \(n) of 7")) }
        shot("02-tour-7"); app.buttons["Finish tour"].tap()
        wait(text("All clear")); shot("03-home-allclear")

        app.tabBars.buttons["Tasks"].tap()
        app.buttons["Add a task"].tap()
        let f = app.textFields["What needs doing?"]; wait(f); f.tap(); f.typeText("UI test task")
        app.textFields["Or a new project name"].tap(); app.textFields["Or a new project name"].typeText("UITestProject")
        app.buttons["Save"].tap()
        wait(text("UI test task")); shot("04-task-added")
        app.buttons["Mark done"].firstMatch.tap(); wait(app.buttons["Mark not done"]); shot("04-task-done")

        app.tabBars.buttons["Home"].tap(); wait(text("UITestProject"), 20, "project progress not shown"); shot("05-home-project")

        app.tabBars.buttons["Notes"].tap()
        app.buttons["New"].tap()
        let t = app.textFields["Title"]; wait(t); t.tap(); t.typeText("UI test note about UITestProject")
        wait(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Looks like this belongs in UITestProject'")).firstMatch, 10, "project suggestion missing")
        shot("06-note-suggestion")
        app.buttons["Save"].tap(); wait(text("UI test note about UITestProject")); shot("06-note-saved")
        app.segmentedControls.buttons["Prompts"].tap(); wait(text("No prompts yet. Tap + to save one.")); shot("06-prompts-empty")

        app.tabBars.buttons["AI"].tap(); wait(app.buttons["Copy setup prompt"], 10, "setup prompt button missing"); shot("07-connect")

        app.tabBars.buttons["More"].tap()
        for th in ["Dark", "Soft Green", "Soft White"] {
            let b = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", th)).firstMatch; wait(b); b.tap(); shot("08-theme-" + th)
        }
        app.buttons["Replay Pip's guide"].tap(); wait(text("Tour 1 of 7")); shot("09-replay")
        app.buttons["Skip guide"].tap(); XCTAssertFalse(text("Tour 1 of 7").exists)
        app.buttons["Sign out"].tap(); wait(app.buttons["guestButton"]); shot("10-signed-out")
    }

    // 03 real email sign-up with random test account, skip tour, data persists across sign-out/in
    func test03_EmailSignUpSignInRoundTrip() {
        let tag = String(Int.random(in: 1000...9999))
        let mail = "projects.reports.ilse+nmui\(tag)@gmail.com"
        let pass = "Nm" + UUID().uuidString.prefix(10) + "!"
        wait(app.buttons["guestButton"])
        app.buttons["New here? Make an account"].tap()
        let email = app.textFields["you@example.com"]; email.tap(); email.typeText(mail)
        let pw = app.secureTextFields["Password"]; pw.tap(); pw.typeText(pass)
        app.buttons["Make my account"].tap()
        wait(text("Tour 1 of 7"), 30, "sign-up did not reach tour. SCREEN: " + screenText()); shot("11-signup-tour")
        app.buttons["Skip guide"].tap(); wait(text("All clear"))
        app.tabBars.buttons["Tasks"].tap(); app.buttons["Add a task"].tap()
        let f = app.textFields["What needs doing?"]; wait(f); f.tap(); f.typeText("Persist me"); app.buttons["Save"].tap(); wait(text("Persist me"))
        app.tabBars.buttons["More"].tap(); app.buttons["Sign out"].tap()
        wait(app.buttons["guestButton"])
        let e2 = app.textFields["you@example.com"]; e2.tap(); e2.typeText(mail)
        let p2 = app.secureTextFields["Password"]; p2.tap(); p2.typeText(pass)
        app.buttons["Sign in"].tap()
        wait(app.tabBars.buttons["Tasks"], 30, "sign-in after sign-out failed"); app.tabBars.buttons["Tasks"].tap()
        wait(text("Persist me"), 20, "task did not persist after sign-in"); shot("12-persisted")
    }
}
