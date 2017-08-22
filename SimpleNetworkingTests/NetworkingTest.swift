//
//  NetworkingTest.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 19/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import XCTest
@testable import SimpleNetworking

struct TestJSONDTO : Codable, Equatable {
    var test: String
    //            var testNil = String? = nil
}
func ==(lhs: TestJSONDTO, rhs: TestJSONDTO) -> Bool {
    return lhs.test == rhs.test
}

struct TestResponseDTO : Codable {
    var json: TestJSONDTO
    //            var testNil = String? = nil
}

class NetworkingTest: XCTestCase {
    
    var testSemaphore = DispatchSemaphore(value: 0)
    var testQueue = DispatchQueue(label: "TestQueue")
    let responseDefaultWaitTime = 5 as Double
    
    var rapidQueue = DispatchQueue(label: "RapidQueue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem)
    let testBaseAddress = "https://httpbin.org/"
    var networking = Networking()
    let jsonRequestDict = ["test":"test"]
    
    override func setUp() {
        super.setUp()
        networking = Networking()
        rapidQueue = DispatchQueue(label: "RapidQueue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem)
    }
    
    override func tearDown() {
        rapidQueue.suspend()
        super.tearDown()
    }
    
    //    func testSuccessStatusCodes() { // takes very long time...
    //        let requestsCount = 200
    //        testQueue.async {
    //            let dispatchGroup = DispatchGroup()
    //            for code in 200..<400 {
    //                dispatchGroup.enter()
    //                self.rapidQueue.asyncAfter(deadline: .now() + (Double(code - 200) * self.responseDefaultWaitTime)) {
    //                    self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)"))
    //                        .fulfillmentHandler(on: DispatchQueue.global(qos: .utility)) { _ in
    //                            dispatchGroup.leave()
    //                        }.failureHandler(on: DispatchQueue.global(qos: .utility)) { _ in
    //                            XCTAssert(false, "Network response not OK")
    //                    }
    //                    dispatchGroup.leave()
    //                }
    //            }
    //
    //            dispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {}
    //            XCTAssert(.success == dispatchGroup.wait(timeout: .now() + (Double(requestsCount) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //            self.testSemaphore.signal()
    //        }
    //        XCTAssert(.success == testSemaphore.wait(timeout: .now() + (Double(requestsCount) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //    }
    //
    //
    //    func testErrorStatusCodes() { // takes very very long time...
    //        let requestsCount = 300
    //        testQueue.async {
    //            let dispatchGroup = DispatchGroup()
    //            let innerDispatchGroup = DispatchGroup()
    //            for code in 100..<200 {
    //                innerDispatchGroup.enter()
    //                dispatchGroup.enter()
    //                self.rapidQueue.asyncAfter(deadline: .now() + (Double(code - 200) * self.responseDefaultWaitTime)) {
    //                    self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)"))
    //                        .fulfillmentHandler(on: DispatchQueue.global(qos: .utility)) { _ in
    //                            innerDispatchGroup.leave()
    //                            dispatchGroup.leave()
    //                        }.failureHandler(on: DispatchQueue.global(qos: .utility)) { _ in
    //                            XCTAssert(false, "Network response not OK")
    //                            innerDispatchGroup.leave()
    //                            dispatchGroup.leave()
    //                    }
    //                    innerDispatchGroup.leave()
    //                    dispatchGroup.leave()
    //                }
    //            }
    //            innerDispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {}
    //            XCTAssert(.success == innerDispatchGroup.wait(timeout: .now() + (Double(100) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //            for code in 400..<600 {
    //                dispatchGroup.enter()
    //                self.rapidQueue.asyncAfter(deadline: .now() + (Double(code - 200) * self.responseDefaultWaitTime)) {
    //                    self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)"))
    //                        .fulfillmentHandler(on: DispatchQueue.global(qos: .utility)) { _ in
    //                            dispatchGroup.leave()
    //                        }.failureHandler(on: DispatchQueue.global(qos: .utility)) { _ in
    //                            XCTAssert(false, "Network response not OK")
    //                    }
    //                    dispatchGroup.leave()
    //                }
    //            }
    //
    //            dispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {}
    //            XCTAssert(.success == dispatchGroup.wait(timeout: .now() + (Double(200) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //            self.testSemaphore.signal()
    //        }
    //        XCTAssert(.success == testSemaphore.wait(timeout: .now() + (Double(requestsCount) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //    }
    //
    //    func testMultipleNetworkCalls() {
    //        let requestsCount = 5
    //        testQueue.async {
    //            let dispatchGroup = DispatchGroup()
    //            for offset in 0..<requestsCount {
    //                dispatchGroup.enter()
    //                self.rapidQueue.asyncAfter(deadline: .now() + (Double(offset) * self.responseDefaultWaitTime)) {
    //                    guard let response = self.networking.perform(.get(from: self.testBaseAddress + "/get"))
    //                        .failureHandler(on: DispatchQueue.global(qos: .utility), withHandler: { _ in
    //                            dispatchGroup.leave()}).value else {
    //                                XCTAssert(false, "No response from network!")
    //                                dispatchGroup.leave()
    //                                return
    //                    }
    //                    XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
    //                    dispatchGroup.leave()
    //                }
    //            }
    //
    //            dispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {}
    //            XCTAssert(.success == dispatchGroup.wait(timeout: .now() + (Double(requestsCount) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //            self.testSemaphore.signal()
    //        }
    //        XCTAssert(.success == testSemaphore.wait(timeout: .now() + (Double(requestsCount) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //    }
    //
    //    func testMultipleRapidNetworkCalls() {
    //        let requestsCount = 5
    //        testQueue.async {
    //            let dispatchGroup = DispatchGroup()
    //            for number in 0..<requestsCount {
    //                dispatchGroup.enter()
    //                self.rapidQueue.async { // After(deadline: .now() + (Double(number) * offsetTime))
    //                    guard let response = self.networking.perform(.get(from: "https://www.google.com")).value else {
    //                        XCTAssert(false, "No response from network!")
    //                        dispatchGroup.leave()
    //                        return
    //                    }
    //                    XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
    //                    dispatchGroup.leave()
    //                }
    //            }
    //
    //            dispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {}
    //            XCTAssert(.success == dispatchGroup.wait(timeout: .now() + (Double(requestsCount) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //            self.testSemaphore.signal()
    //        }
    //        XCTAssert(.success == testSemaphore.wait(timeout: .now() + (Double(requestsCount) * self.responseDefaultWaitTime)), "Not in time - possible deadlock or fail")
    //    }
    
    
    
    func testGETRequest() {
        testQueue.async {
            guard let response = self.networking.perform(.get(from: self.testBaseAddress + "get")).value else {
                XCTAssert(false, "No response from network!")
                return
            }
            XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + self.responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testPOSTRequest() {
        testQueue.async {
            let jsonData = try! JSONSerialization.data(withJSONObject: self.jsonRequestDict, options: .prettyPrinted)
            guard let response = self.networking.perform(.post(data: jsonData, type: .json(encoded: .utf8), to: self.testBaseAddress + "post")).value else {
                XCTAssert(false, "No response from network!")
                return
            }
            XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
            guard let responseData = response.data else {
                XCTAssert(false, "No data from network!")
                return
            }
            guard let jsonObject = try? JSONSerialization.jsonObject(with: responseData), let json = jsonObject as? [String:Any] else {
                XCTAssert(false, "Not json from network!")
                return
            }
            
            let jsonUnwrappedResponse = json["json"] as! [String:String]
            XCTAssert(jsonUnwrappedResponse == self.jsonRequestDict, "Network response don't match request")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + self.responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    
    
    func testJSONTransformPOSTRequest() {
        let testTransportObject = TestJSONDTO(test: "test")
        testQueue.async {
            let jsonData = try! testTransportObject.jsonData()
            guard let responseDTO = self.networking
                .perform(.post(data: jsonData, type: .json(encoded: .utf8), to: self.testBaseAddress + "post"))
                .fulfillmentHandler(on: .global(), withHandler: { response in
                    XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
                })
                .jsonTransform(to: TestResponseDTO.self)
                .failureHandler(on: .global(), withHandler: { error in
                    XCTAssert(false, "Error when deserializing json \(error)")
                })
                .value?.json
                else {
                    XCTAssert(false, "No or bad response from network!")
                    return
            }
            
            XCTAssert(responseDTO == testTransportObject, "Network response don't match request")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + self.responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testDownloadRequest() {
        testQueue.async {
            let bytesToDownload = 102400
            var progressRecived = false
            
            let promise = self.networking.perform(.download(from: self.testBaseAddress + "bytes/\(bytesToDownload)", savingTo: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("test.data")))
            
            promise.progressHandler(on: DispatchQueue.global()) { _ in
                progressRecived = true
            }
            guard let response = promise.value else {
                XCTAssert(false, "No response from network!")
                return
            }
            XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
            XCTAssert(progressRecived, "Progress not recived")
            guard let responseData = response.data else {
                XCTAssert(false, "No data from network!")
                return
            }
            XCTAssert(responseData.count == bytesToDownload, "Network data size don't match expected")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + self.responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testRedirection() {
        testQueue.async {
            var redirectionHandled = false
            self.networking.redirectionHandler = { session, request in
                redirectionHandled = true
                return request
            }
            guard let response = self.networking.perform(.get(from: self.testBaseAddress + "redirect/3")).value else {
                XCTAssert(false, "No response from network!")
                return
            }
            
            XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
            XCTAssert(redirectionHandled, "Redirection not handled")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + self.responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testRedirectionCancel() {
        testQueue.async {
            self.networking.redirectionHandler = { _ in
                return nil
            }
            let response = self.networking.perform(.get(from: self.testBaseAddress + "redirect-to?url=httpbin.org/get")).value
            XCTAssert(response == nil, "Redirection cancel not performed")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + self.responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
}
