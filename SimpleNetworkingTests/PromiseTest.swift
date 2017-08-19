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
    
    override func setUp() {
        super.setUp()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    override func tearDown() {
        semaphore.signal()
        super.tearDown()
    }
    
    func testFulfillValue() {
        let promise = FailablePromise<Void>()
        DispatchQueue.global().async {
            promise.send(.fulfill(with: ()))
        }
        XCTAssert(promise.value != nil, "Promise value not fulfilled")
    }
    
    func testFailValue() {
        let promise = FailablePromise<Void>()
        DispatchQueue.global().async {
            promise.send(.fail(with: "FAIL"))
        }
        XCTAssert(promise.value == nil, "Promise value not failed")
    }
    
    func testCallbackFulfillValue() {
        let promise = FailablePromise<Void>()
        promise.fulfillmentHandler(on: DispatchQueue.global()) { _ in
            self.semaphore.signal()
            
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            promise.send(.fulfill(with: ()))
        }
        
        XCTAssert(.success == semaphore.wait(timeout: .now() + 3), "Not in time - possible deadlock or fail")
    }
    
    func testCallbackFailValue() {
        let promise = FailablePromise<Void>()
        promise.failureHandler(on: DispatchQueue.global()) { _ in
            self.semaphore.signal()
            
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            promise.send(.fail(with: "FAIL"))
        }
        
        XCTAssert(.success == semaphore.wait(timeout: .now() + 3), "Not in time - possible deadlock or fail")
    }
    
    func testInstantCallbackFulfillValue() {
        let promise = FailablePromise<Void>()
        promise.send(.fulfill(with: ()))
        promise.fulfillmentHandler(on: DispatchQueue.global()) { _ in
            self.semaphore.signal()
            
        }
        
        XCTAssert(.success == semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
    }
    
    func testInstantCallbackFailValue() {
        let promise = FailablePromise<Void>()
        promise.send(.fail(with: "FAIL"))
        promise.failureHandler(on: DispatchQueue.global()) { _ in
            self.semaphore.signal()
            
        }
        
        XCTAssert(.success == semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
    }
    
    func testProgressHandler() {
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
    }
    
    func testTransformValue() {
        let parentPromise = FailablePromise<Void>()
        let promise = parentPromise.transform { _ in return .success(with:()) }
        DispatchQueue.global().async {
            parentPromise.send(.fulfill(with: ()))
        }
        XCTAssert(promise.value != nil, "Transformed promise value not fulfilled")
    }
    
    func testTransformFailure() {
        let parentPromise = FailablePromise<Void>()
        let promise = parentPromise.transform { _ in return .success(with:()) }
        DispatchQueue.global().async {
            parentPromise.send(.fail(with: "FAIL"))
        }
        XCTAssert(promise.value == nil, "Transformed promise value not fulfilled")
    }
    
    func testFailedTransform() {
        let parentPromise = FailablePromise<Void>()
        let promise: FailablePromise<Void> = parentPromise.transform { _ in return .failure(reason:"FAIL") }
        DispatchQueue.global().async {
            parentPromise.send(.fulfill(with: ()))
        }
        XCTAssert(promise.value == nil, "Transformed promise value not fulfilled")
    }
    
    func testMessageBeforeTransformInstantCallbackFulfillValue() {
        let parentPromise = FailablePromise<Void>()
        parentPromise.send(.fulfill(with: ()))
        let promise = parentPromise.transform { _ in return .success(with:()) }
        promise.fulfillmentHandler(on: DispatchQueue.global()) { _ in
            self.semaphore.signal()
        }
        
        XCTAssert(.success == semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
    }
    
    func testMessageBeforeTransformInstantCallbackFailValue() {
        let parentPromise = FailablePromise<Void>()
        parentPromise.send(.fail(with: "FAIL"))
        let promise = parentPromise.transform { _ in return .success(with:()) }
        promise.failureHandler(on: DispatchQueue.global()) { _ in
            self.semaphore.signal()
        }
        
        XCTAssert(.success == semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
    }
    
    func testMessageAfterTransformInstantCallbackFulfillValue() {
        let parentPromise = FailablePromise<Void>()
        let promise = parentPromise.transform { _ in return .success(with:()) }
        parentPromise.send(.fulfill(with: ()))
        promise.fulfillmentHandler(on: DispatchQueue.global()) { _ in
            self.semaphore.signal()
        }
        
        XCTAssert(.success == semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
    }
    
    func testMessageAfterTransformInstantCallbackFailValue() {
        let parentPromise = FailablePromise<Void>()
        let promise = parentPromise.transform { _ in return .success(with:()) }
        parentPromise.send(.fail(with: "FAIL"))
        promise.failureHandler(on: DispatchQueue.global()) { _ in
            self.semaphore.signal()
        }
        
        XCTAssert(.success == semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
    }
    
    func testTransformProgressHandler() {
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
    }
    
    func testProgressPerformance() {
        let count:Int64 = 10000
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
                XCTAssert(.success == self.semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
            }
        }
        promise.send(.fulfill(with: ()))
        promise.value // locks thread until complete
        XCTAssert(progressRecived, "Progress not recived")
    }
    
    func testTransformedProgressPerformance() {
        let count:Int64 = 10000
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
                XCTAssert(.success == self.semaphore.wait(timeout: .now() + 1), "Not in time - possible deadlock or fail")
            }
        }
        parentPromise.send(.fulfill(with: ()))
        promise.value // locks thread until complete
        XCTAssert(progressRecived, "Progress not recived")
    }
}

