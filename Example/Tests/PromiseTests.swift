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
        Promise<Void> { resolve, _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                resolve(())
            }
        }
        .then({ exp.fulfill() })
        .catch { _ in XCTFail("Failed to execute the right handler") }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testThenReturningPromise() {
        let exp = expectation(description: "Execute then hanlers after fulfillment")
        Promise<Void> { resolve, _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                resolve(())
            }
        }
        .then { return Promise.resolve(true) }
        .then {
            XCTAssert($0)
            exp.fulfill()
        }
        .catch { _ in XCTFail("Failed to execute the right handler")}
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testThenReturningNewValue() {
        let exp = expectation(description: "Execute then handlers after fulfillment")
        Promise<Void> { resolve, _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                resolve(())
            }
        }
        .then { return "Success" }
        .then { value in
            XCTAssertEqual(value, "Success")
            exp.fulfill()
        }
        .catch { _ in XCTFail("Failed to execute the right handler") }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCatch() {
        let exp = expectation(description: "Execute catch handler after rejection")
        Promise<String> { _, reject in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                reject(TestError())
            }
        }
        .then { _ in XCTFail("Failed to execute the right handler") }
        .catch { _ in exp.fulfill() }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testRecoverReturningPromise() {
        let exp = expectation(description: "Execute recover handler after rejection")
        Promise<String> { _, reject in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                reject(TestError())
            }
        }
        .recover { _ -> Promise<String> in
            exp.fulfill()
            return Promise.resolve("Success")
        }
        .then { XCTAssert($0 == "Success") }
        .catch { _ in XCTFail("Failed to execute the right handler") }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testRecoverReturningNewValue() {
        let exp = expectation(description: "Execute recover handler after rejection")
        Promise<Bool> { _, reject in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                reject(TestError())
            }
        }
        .recover { _ -> Bool in
            exp.fulfill()
            return true
        }
        .then { XCTAssert($0) }
        .catch { _ in XCTFail("Failed to execute the right handler") }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFinally() {
        let exp1 = expectation(description: "Execute finally handler after fulfillment")
        Promise<Void> { resolve, _ in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                resolve(())
            }
        }
        .finally { exp1.fulfill() }
        
        let exp2 = expectation(description: "Execute finally handler after rejection")
        Promise<Void> { _, reject in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                reject(TestError())
            }
        }
        .finally { exp2.fulfill() }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testResolveTypeMethod() {
        let exp = expectation(description: "Execute then handler after fulfillment")
        Promise<Void>.resolve(()).then {
            exp.fulfill()
        }
        .catch { _ in
            XCTFail("Failed to execute the right handler")
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testRejectTypeMethod() {
        let exp = expectation(description: "Execute catch handler after rejection")
        Promise<Void>.reject(TestError()).then {
            XCTFail("Failed to execute the right handler")
        }
        .catch { _ in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testAllTypeMethod() {
        let exp = expectation(description: "Execute then handler after all promises are fulfilled")
        let promises = [
            Promise<Int> { resolve, _ in
                resolve(1)
            },
            Promise<Int> { resolve, _ in
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.2) {
                    resolve(2)
                }
            },
            Promise.resolve(3),
            Promise<Int> { resolve, _ in
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                    resolve(4)
                }
            }
        ]
        Promise.all(promises).then {
            exp.fulfill()
            XCTAssertEqual($0, [1, 2, 3, 4])
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testRaceTypeMethod() {
        let exp = expectation(description: "Execute then handler after first promise fulfillment")
        let promises = [
            Promise<Int> { resolve, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    resolve(1)
                }
            },
            Promise.resolve(2),
            Promise<Int> { resolve, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    resolve(3)
                }
            },
            Promise<Int> { resolve, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    resolve(4)
                }
            }
        ]
        Promise.race(promises).then {
            exp.fulfill()
            XCTAssertEqual($0, 2)
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDispatching() {
        var time1: DispatchTime!
        var time2: DispatchTime!
        
        Promise<Int> { resolve, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resolve(1)
            }
        }
        .then(on: DispatchQueue.global(qos: .background)) { value in
            return 2
        }
        .then(on: DispatchQueue.global(qos: .utility), { value in
            time1 = DispatchTime.now()
        })
        .then(on: DispatchQueue.global(qos: .default)) { value in
            time2 = DispatchTime.now()
            XCTAssert(time2 > time1)
        }
    }
    
}
