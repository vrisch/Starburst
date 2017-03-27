//
//  StarburstTests.swift
//  Starburst
//
//  Created by Magnus Nilsson on 2017-03-11.
//  Copyright © 2017 Starburst. All rights reserved.
//

import Foundation
import XCTest
import Starburst

class StarburstTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        //// XCTAssertEqual(Starburst().text, "Hello, World!")
    }
}

#if os(Linux)
extension StarburstTests {
    static var allTests : [(String, (StarburstTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
#endif
