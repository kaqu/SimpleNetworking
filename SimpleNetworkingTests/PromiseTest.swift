//
//  PromiseTest.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 19/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import XCTest
@testable import SimpleNetworking

class PromiseTest: XCTestCase {
    
    var semaphore = DispatchSemaphore(value: 0)
    var testSemaphore = DispatchSemaphore(value: 0)
    var testQueue = DispatchQueue(label: "TestQueue")
    
    let defaultWaitTime = 1 as Double
    
    override func setUp() {
        super.setUp()
        semaphore = DispatchSemaphore(value: 0)
        testSemaphore = DispatchSemaphore(value: 0)
        testQueue = DispatchQueue(label: "TestQueue")
    }
    
    override func tearDown() {
        semaphore.signal()
        super.tearDown()
    }
    
    func testFulfillValue() {
        testQueue.async {
            let promise = FailablePromise<Void>()
            DispatchQueue.global().async {
                promise.send(.fulfill(with: ()))
            }
            XCTAssert(promise.value != nil, "Promise value not fulfilled")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testFailValue() {
        testQueue.async {
            let promise = FailablePromise<Void>()
            DispatchQueue.global().async {
                promise.send(.fail(with: "FAIL"))
            }
            XCTAssert(promise.value == nil, "Promise value not failed")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testCallbackFulfillValue() {
        testQueue.async {
            let promise = FailablePromise<Void>()
            promise.fulfillmentHandler(on: DispatchQueue.global()) { _ in
                self.semaphore.signal()
                
            }
            DispatchQueue.global().async/*After(deadline: .now() + 1)*/ {
                promise.send(.fulfill(with: ()))
            }
            
            XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testCallbackFailValue() {
        testQueue.async {
            let promise = FailablePromise<Void>()
            promise.failureHandler(on: DispatchQueue.global()) { _ in
                self.semaphore.signal()
                
            }
            DispatchQueue.global().async/*After(deadline: .now() + 1)*/ {
                promise.send(.fail(with: "FAIL"))
            }
            
            XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testInstantCallbackFulfillValue() {
        testQueue.async {
            let promise = FailablePromise<Void>()
            promise.send(.fulfill(with: ()))
            promise.fulfillmentHandler(on: DispatchQueue.global()) { _ in
                self.semaphore.signal()
                
            }
            
            XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testInstantCallbackFailValue() {
        testQueue.async {
            let promise = FailablePromise<Void>()
            promise.send(.fail(with: "FAIL"))
            promise.failureHandler(on: DispatchQueue.global()) { _ in
                self.semaphore.signal()
                
            }
            
            XCTAssert(.success == self.semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testProgressHandler() {
        testQueue.async {
            let promise = FailablePromise<Void>()
            var progressRecived = false
            promise.progressHandler(on: DispatchQueue.global()) { _ in
                progressRecived = true
            }
            DispatchQueue.global().async {
                promise.send(.progress(value: Progress()))
                promise.send(.fulfill(with: ()))
            }
            promise.value // locks thread until complete
            XCTAssert(progressRecived, "Progress not recived")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testTransformValue() {
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            let promise = parentPromise.transform { _ in return .success(with:()) }
            DispatchQueue.global().async {
                parentPromise.send(.fulfill(with: ()))
            }
            XCTAssert(promise.value != nil, "Transformed promise value not fulfilled")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testTransformFailure() {
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            let promise = parentPromise.transform { _ in return .success(with:()) }
            DispatchQueue.global().async {
                parentPromise.send(.fail(with: "FAIL"))
            }
            XCTAssert(promise.value == nil, "Transformed promise value not fulfilled")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testFailedTransform() {
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            let promise: FailablePromise<Void> = parentPromise.transform { _ in return .failure(reason:"FAIL") }
            DispatchQueue.global().async {
                parentPromise.send(.fulfill(with: ()))
            }
            XCTAssert(promise.value == nil, "Transformed promise value not fulfilled")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testMessageBeforeTransformInstantCallbackFulfillValue() {
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            parentPromise.send(.fulfill(with: ()))
            let promise = parentPromise.transform { _ in return .success(with:()) }
            promise.fulfillmentHandler(on: DispatchQueue.global()) { _ in
                self.semaphore.signal()
            }
            
            XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testMessageBeforeTransformInstantCallbackFailValue() {
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            parentPromise.send(.fail(with: "FAIL"))
            let promise = parentPromise.transform { _ in return .success(with:()) }
            promise.failureHandler(on: DispatchQueue.global()) { _ in
                self.semaphore.signal()
            }
            
            XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testMessageAfterTransformInstantCallbackFulfillValue() {
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            let promise = parentPromise.transform { _ in return .success(with:()) }
            parentPromise.send(.fulfill(with: ()))
            promise.fulfillmentHandler(on: DispatchQueue.global()) { _ in
                self.semaphore.signal()
            }
            
            XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testMessageAfterTransformInstantCallbackFailValue() {
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            let promise = parentPromise.transform { _ in return .success(with:()) }
            parentPromise.send(.fail(with: "FAIL"))
            promise.failureHandler(on: DispatchQueue.global()) { _ in
                self.semaphore.signal()
            }
            
            XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testTransformProgressHandler() {
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            let promise = parentPromise.transform { _ in return .success(with:()) }
            var progressRecived = false
            promise.progressHandler(on: DispatchQueue.global()) { _ in
                progressRecived = true
            }
            DispatchQueue.global().async {
                parentPromise.send(.progress(value: Progress()))
                parentPromise.send(.fulfill(with: ()))
            }
            promise.value // locks thread until complete
            XCTAssert(progressRecived, "Progress not recived")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + defaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testProgressPerformance() {
        let count:Int64 = 10000
        testQueue.async {
            let promise = FailablePromise<Void>()
            var progressRecived = false
            promise.progressHandler(on: DispatchQueue.global(qos: .userInteractive)) { progress in
                progressRecived = progress.completedUnitCount == count
                self.semaphore.signal()
            }
            
            self.measure {
                for completed in 0...count {
                    let progress = Progress(totalUnitCount: count)
                    progress.completedUnitCount = completed
                    promise.send(.progress(value: progress))
                    XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
                }
            }
            promise.send(.fulfill(with: ()))
            promise.value // locks thread until complete
            XCTAssert(progressRecived, "Progress not recived")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + (Double(count) * defaultWaitTime)), "Not in time - possible deadlock or fail")
    }
    
    func testTransformedProgressPerformance() {
        let count:Int64 = 10000
        testQueue.async {
            let parentPromise = FailablePromise<Void>()
            let promise = parentPromise.transform { _ in return .success(with:()) }
            var progressRecived = false
            promise.progressHandler(on: DispatchQueue.global(qos: .userInteractive)) { progress in
                progressRecived = progress.completedUnitCount == count
                self.semaphore.signal()
            }
            
            self.measure {
                for completed in 0...count {
                    let progress = Progress(totalUnitCount: count)
                    progress.completedUnitCount = completed
                    parentPromise.send(.progress(value: progress))
                    XCTAssert(.success == self.semaphore.wait(timeout: .now() + self.defaultWaitTime), "Not in time - possible deadlock or fail")
                }
            }
            parentPromise.send(.fulfill(with: ()))
            promise.value // locks thread until complete
            XCTAssert(progressRecived, "Progress not recived")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + (Double(count) * defaultWaitTime)), "Not in time - possible deadlock or fail")
    }
}

