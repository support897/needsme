import XCTest

final class ScreenshotTour: XCTestCase {
    let app = XCUIApplication()
    func shot(_ n: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = n; a.lifetime = .keepAlways; add(a)
        if let d = ProcessInfo.processInfo.environment["SHOT_DIR"] { try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: d + "/" + n + ".png")) }
    }
    func tapTab(_ n: String, _ out: String) {
        let b = app.buttons["tab-" + n]
        if b.waitForExistence(timeout: 8) { b.tap(); Thread.sleep(forTimeInterval: 2.5); shot(out) }
    }
    func testTour() {
        app.launchArguments = ["-uitest-reset", "-uitest-noask"]; app.launch()
        let em = app.buttons["emailButton"]; _ = em.waitForExistence(timeout: 30); shot("00-door")
        em.tap()
        let email = app.textFields["you@example.com"]; _ = email.waitForExistence(timeout: 15)
        app.buttons["switchMode"].tap(); Thread.sleep(forTimeInterval: 1)
        email.tap(); email.typeText("appreview@needsme.xyz")
        let pw = app.secureTextFields.firstMatch; pw.tap(); pw.typeText("NeedsMeReview#2026")
        let go = app.keyboards.buttons["Go"]; if go.waitForExistence(timeout: 3) { go.tap() } else { app.buttons["emailSubmit"].tap() }
        Thread.sleep(forTimeInterval: 12); shot("01-after-login"); try? app.debugDescription.write(toFile: (ProcessInfo.processInfo.environment["SHOT_DIR"] ?? "/tmp") + "/tree.txt", atomically: true, encoding: .utf8)
        let skip = app.buttons["Skip guide"]
        if skip.waitForExistence(timeout: 40) { shot("01-guide"); skip.tap() }
        Thread.sleep(forTimeInterval: 3)
        tapTab("Home", "02-home")
        tapTab("Chats", "03-chats")
        tapTab("AIs", "04-ais")
        tapTab("Needs Me", "05-needs-me")
    }
}
