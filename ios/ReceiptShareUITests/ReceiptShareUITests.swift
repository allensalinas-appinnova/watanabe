import XCTest

final class ReceiptShareUITests: XCTestCase {
  func testNativePDFAndImageShare() throws {
    continueAfterFailure = false
    let sender = XCUIApplication(bundleIdentifier:"co.appinnova.lumio.qa.sender")
    let lumio = XCUIApplication(bundleIdentifier:"com.appinnova.lumiomoney.app")
    lumio.terminate()
    for button in ["Share PDF","Share image"] {
      sender.terminate(); sender.launch()
      sender.buttons[button].tap()
      var option = sender.descendants(matching:.any).matching(identifier:"LumioMoney").firstMatch
      if !option.waitForExistence(timeout:5) {
        let more = sender.cells.matching(NSPredicate(format:"label == 'More'")).firstMatch
        if more.exists { more.tap() }
        option = sender.descendants(matching:.any).matching(identifier:"LumioMoney").firstMatch
      }
      XCTAssertTrue(option.waitForExistence(timeout:10),"LumioMoney must appear in the native share sheet")
      option.tap()
      XCTAssertTrue(lumio.wait(for:.runningForeground,timeout:20),"Share extension must open LumioMoney")
      let email = "native-share@example.test"
      XCTAssertTrue(email.hasSuffix("@example.test"), "Synthetic Emulator email required")
      var enteredLogin = false
      var invitationAccepted = false
      for _ in 0..<24 {
        if lumio.buttons["Analyze document"].exists { break }
        let address = lumio.descendants(matching:.any).matching(identifier:"you@example.com").firstMatch
        if lumio.staticTexts["Shared file"].exists, let login = lumio.buttons.matching(identifier:"Log in").allElementsBoundByIndex.last {
          login.tap(); invitationAccepted = true; continue
        }
        if invitationAccepted, !enteredLogin, address.exists, address.isHittable {
          address.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
          // Exercise the form's native Next/Done keyboard actions without querying
          // Flutter secure input through the runtime's inconsistent AX element type.
          lumio.typeText(email + "\n")
          lumio.typeText("Synthetic-QA-12345\n")
          enteredLogin = true; continue
        }
        if invitationAccepted, (!address.exists || !address.isHittable), let login = lumio.buttons.matching(identifier:"Log in").allElementsBoundByIndex.last, login.exists {
          login.tap(); continue
        }
        let replace = lumio.buttons["Use new file"]
        if replace.exists { replace.tap();continue }
        let confirm = lumio.buttons["Continue"]
        if confirm.exists { confirm.tap();continue }
        _ = lumio.buttons["Analyze document"].waitForExistence(timeout:1)
      }
      XCTAssertTrue(lumio.buttons["Analyze document"].waitForExistence(timeout:20),"Shared receipt preview must be ready without analyzing")
      let screenshot = XCTAttachment(screenshot:lumio.screenshot());screenshot.name = button;screenshot.lifetime = .keepAlways;add(screenshot)
    }
  }
}
