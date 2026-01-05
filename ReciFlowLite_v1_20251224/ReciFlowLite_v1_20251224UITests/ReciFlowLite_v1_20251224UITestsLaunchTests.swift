//
//  ReciFlowLite_v1_20251224UITestsLaunchTests.swift
//  ReciFlowLite_v1_20251224UITests
//
//  Created by 木嶋育朗 on 2025/12/24.
//

import XCTest

final class ReciFlowLite_v1_20251224UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
