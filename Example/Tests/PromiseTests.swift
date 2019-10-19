//
//  PromiseTests.swift
//  Promisor_Tests
//
//  Created by Ennio Bovyn on 05/05/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import Promisor

class PromiseTests: XCTestCase {
    
    struct TestError: Error {}

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExecutorExecution() {
        let exp = expectation(description: "Execute the executor function immediately")
        _ = Promise<Int> { _, _ in exp.fulfill() }
        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func testThen() {
        let exp = expectation(description: "Execute then handler after fulfillment")
        Promise<()> { resolve, _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                resolve(())
            }
        }
        .then({ exp.fulfill() })
        .catch { _ in XCTFail("Failed to execute the right handler") }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testThenReturningNewValue() {
        let exp = expectation(description: "Execute then handlers after fulfillment")
        Promise<()> { resolve, _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                resolve(())
            }
        }
        .then { return "Success" }
        .then { value in
            XCTAssertEqual(value, "Success")
            exp.fulfill()
        }
        .catch { _ in XCTFail("Failed to execute the right handler") }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testThenReturningPromise() {
        
    }
    
    func testCatch() {
        let exp = expectation(description: "Execute catch handler after rejection")
        Promise<String> { _, reject in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                reject(TestError())
            }
        }
        .then { _ in XCTFail("Failed to execute the right handler") }
        .catch { _ in exp.fulfill() }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testFinally() {
        let exp1 = expectation(description: "Execute finally handler after fulfillment")
        Promise<()> { resolve, _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                resolve(())
            }
        }
        .finally { exp1.fulfill() }
        
        let exp2 = expectation(description: "Execute finally handler after rejection")
        Promise<()> { _, reject in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                reject(TestError())
            }
        }
        .finally { exp2.fulfill() }
        
        waitForExpectations(timeout: 4, handler: nil)
    }
    
    func testResolveTypeMethod() {
        
    }

}
