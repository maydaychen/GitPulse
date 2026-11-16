import XCTest
import UIKit

final class TeaPulseSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLoginThemeChangesWhilePresented() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode", "--login-screen"]
        app.launch()
        let menu = app.buttons["loginThemeMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))

        menu.tap()
        app.buttons["themeOption-深色"].tap()
        XCTAssertLessThan(try backgroundBrightness(app.screenshot().image), 0.3)
        menu.tap()
        app.buttons["themeOption-浅色"].tap()
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Login Light Mode"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(try backgroundBrightness(screenshot.image), 0.85,
            "Choosing light mode must update the presented login background")
    }

    @MainActor
    func testProbeResultsFollowLightTheme() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode", "--login-screen"]
        app.launch()
        let menu = app.buttons["loginThemeMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        app.buttons["themeOption-浅色"].tap()

        // Use an invalid local input so this visual check never contacts a real server.
        let address = app.textFields["onboardingField-公网反代地址"]
        address.tap()
        let oldValue = try XCTUnwrap(address.value as? String)
        address.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count) + "invalid\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        let probe = app.buttons["loginProbeButton"]
        for _ in 0..<3 where !probe.isHittable { app.swipeUp() }
        probe.tap()
        let results = app.otherElements["loginProbeResults"]
        XCTAssertTrue(results.waitForExistence(timeout: 5))
        let diagnostic = app.staticTexts["地址格式无效，请检查协议与端口"]
        for _ in 0..<3 where !diagnostic.isHittable { app.swipeUp() }
        XCTAssertTrue(diagnostic.isHittable)
        XCTAssertTrue(app.frame.contains(results.frame))
        let image = results.screenshot().image
        XCTAssertGreaterThan(try backgroundBrightness(image, at: CGPoint(x: image.size.width / 2, y: 3)), 0.85,
            "Diagnostics use a light surface instead of the fixed dark code surface")
        let attachment = XCTAttachment(image: image)
        attachment.name = "Light Probe Results"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func backgroundBrightness(_ image: UIImage, at point: CGPoint? = nil) throws -> Double {
        let cgImage = try XCTUnwrap(image.cgImage)
        let location = point ?? CGPoint(x: 8, y: image.size.height / 2)
        let pixel = try XCTUnwrap(cgImage.cropping(to: CGRect(
            x: location.x * image.scale, y: location.y * image.scale, width: 1, height: 1)))
        var rgba = [UInt8](repeating: 0, count: 4)
        try rgba.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return rgba.prefix(3).map(Double.init).reduce(0, +) / (255 * 3)
    }

    @MainActor
    func testPrimaryTabsAndEndpointPillExistInDemoMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode"]
        app.launch()

        XCTAssertTrue(app.buttons["endpointProbePill"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyPATKeepsLoginAndShowsFailure() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode", "--login-screen"]
        app.launch()
        let connect = app.buttons["loginPrimaryConnectButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        connect.tap()
        XCTAssertTrue(app.staticTexts["loginConnectionError"].waitForExistence(timeout: 5))
        XCTAssertTrue(connect.exists)
    }

    @MainActor
    func testLoginOnboardingScreenLaunchesAndEntersDemoSandbox() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode", "--login-screen"]
        app.launch()

        XCTAssertTrue(app.buttons["loginPrimaryConnectButton"].waitForExistence(timeout: 5))
        let demoBtn = app.buttons["loginDemoModeButton"]
        XCTAssertTrue(demoBtn.exists)
        demoBtn.tap()
        XCTAssertTrue(app.buttons["endpointProbePill"].waitForExistence(timeout: 5))
    }
}
