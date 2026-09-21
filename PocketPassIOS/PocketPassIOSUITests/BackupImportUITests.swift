import XCTest

final class BackupImportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEncryptedBackupSelectionCompletesImport() throws {
        let app = XCUIApplication()
        app.launchEnvironment["POCKETPASS_UI_TEST_BACKUP_BASE64"] = "UE9DS0VUUEFTUzEAAQIDBAUGBwgJCgsMDQ4PAAECAwQFBgcICQoLm2UssV7BbnmyTTogNzGDCLQSF5wjcAjhQRRuArQcrofDLr22ECxz2X0ZXyrWiPn6l41BNrXqorW9LxAjHgcMT+dgWUPTrQHmdenihKFz1z/4YtTvWAtV9B2QLvnGqqfMJXQENTq1fYyuF79HLJR6cxAjXnCFZF9WNFRlxRW7mXgi0u2+4j1Kb05WJjvrrF+I2e/xVyUQ8CypRRUi3q5IFgGcYB3Edv37HHBadfX3i9ZKx6KxX9CswXqOZb6rm43yftXJ6pRFHkyy95ZqNQplZ8OHLDeWQUDjQKRknA8VEOTBgBMFGB/9f4JZT+aXRPzybm0+HzcBEw35HsbMTeJOoaFayw0WS/3RN3Jl45KdU2QQsJBGrOcl+/oX3EFptM6eXSNGLN+ws1t5a3B8paOxdAEgvBcpJs59RcLZACsUM6oBFBBRosodHmSmb0gCt0vKvRycanvLy19tIYan90Hr06c0NuqyI/S24EF+CCBIJH2BqfDE+EWL1i3IgZajKNzptRCUDqMLPxGUiLEAedIMl/LWsYHRTl6pUKShlsy2LFKt0nuE1vMaptxE+knpFNyE9O/QfbnccRgGJrjCwuS214ruRh2potpPWMs2OIJssmIo4D9Bx4hNLgnDBXR9LKdeoskUDfV1FQJSU97mJ72d3xX0O2XI8AJsUrbe+u83xonaWG6FeJoyFtZR1i9bX/X8hYspM5/g0puuPaLuvu5qtUcTeAPm8S+KDpcUtW/OGjD3g1loIBMnUXx7UQHbU8RhpVqV1WFcQyLnoJphF6gCxCztjl6JPK8n+cYumzazpzg8HJTzFlmN9NcWUfHLeqcfnaxjjVLg8TV5DivuAFL7QPV1NqyVImWQ+A=="
        app.launch()

        XCTAssertTrue(app.buttons["设置"].waitForExistence(timeout: 10))
        app.buttons["设置"].tap()

        let importRow = app.buttons["导入数据"]
        for _ in 0..<3 where !importRow.exists {
            app.swipeUp()
        }
        XCTAssertTrue(importRow.waitForExistence(timeout: 10))
        importRow.tap()

        let chooseButton = app.buttons["选择文件并导入"]
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 10))
        chooseButton.tap()

        let fixture = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "PocketPass-Import-Test.pocketpass")).firstMatch
        if !fixture.waitForExistence(timeout: 3) {
            let localStorage = app.cells.matching(NSPredicate(
                format: "label IN %@",
                ["我的iPad", "我的 iPad", "在我的 iPad 上", "On My iPad"]
            )).firstMatch
            XCTAssertTrue(localStorage.waitForExistence(timeout: 10), "The iPad picker must expose local storage")
            localStorage.tap()

            let pocketPassFolder = app.cells
                .matching(NSPredicate(format: "label CONTAINS %@ OR identifier CONTAINS %@", "口袋密码", "口袋密码"))
                .firstMatch
            XCTAssertTrue(pocketPassFolder.waitForExistence(timeout: 10), "The iPad picker must expose the PocketPass document folder")
            pocketPassFolder.tap()
        }
        XCTAssertTrue(fixture.waitForExistence(timeout: 10), "The picker must show the supported .pocketpass fixture")
        let jsonFixture = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "PocketPass-Import-Test.json")).firstMatch
        XCTAssertTrue(jsonFixture.exists && jsonFixture.isEnabled, "Supported .json files must be selectable")
        let unsupported = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "PocketPass-Unsupported")).firstMatch
        XCTAssertTrue(unsupported.exists, "The unsupported fixture should remain visible for filter verification")
        XCTAssertFalse(unsupported.isEnabled, "Unsupported files must not be selectable")
        fixture.tap()

        let password = app.secureTextFields["加密备份密码"]
        XCTAssertTrue(password.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["该备份已加密，请输入 Mac 端导出时设置的密码。"].exists)
        password.tap()
        password.typeText("PocketPass-Test-2026")
        app.buttons["导入"].tap()

        let completed = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "导入完成：")).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 15), "A selected encrypted backup must complete import and show counts")
    }
}
