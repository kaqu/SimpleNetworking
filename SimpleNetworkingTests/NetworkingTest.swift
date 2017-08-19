//
//  NetworkingTest.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 19/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import XCTest
@testable import SimpleNetworking

class NetworkingTest: XCTestCase {
    
    let testBaseAddress = "https://httpbin.org/"
    var networking = Networking()
    let jsonRequestDict = ["test":"test"]
    
    override func setUp() {
        super.setUp()
        networking = Networking()
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
    
    func testSuccessStatusCodes() {
        let dispatchGroup = DispatchGroup()
        let code = 200
        //        for code in 200..<400 {
        dispatchGroup.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)"))
                .fulfillmentHandler(on: DispatchQueue.global(qos: .utility)) { _ in
                    dispatchGroup.leave()
                }.failureHandler(on: DispatchQueue.global(qos: .utility)) { _ in
                    dispatchGroup.leave()
            }
            //                XCTAssert(nil == self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)")).value, "Network responded while should not")
            //                dispatchGroup.leave()
        }
        //            guard let response = self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)")).value else {
        //                XCTAssert(false, "No response from network!")
        //                return
        //            }
        //            XCTAssert(response.statusCode == code, "Network response not OK - status: \(response.statusCode)")
        //
        dispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {}
        XCTAssert(.success == dispatchGroup.wait(timeout: .now() + 5), "Not in time - possible deadlock or fail")
    }
    
    
    func testErrorStatusCodes() {
        let dispatchGroup = DispatchGroup()
        for code in 100..<200 {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInteractive).async {
                self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)"))
                    .fulfillmentHandler(on: DispatchQueue.global(qos: .utility)) { _ in
                        dispatchGroup.leave()
                    }.failureHandler(on: DispatchQueue.global(qos: .utility)) { _ in
                        dispatchGroup.leave()
                }
                //                XCTAssert(nil == self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)")).value, "Network responded while should not")
                //                dispatchGroup.leave()
            }
        }
        
        for code in 400..<600 {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInteractive).async {
                self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)"))
                    .fulfillmentHandler(on: DispatchQueue.global(qos: .utility)) { _ in
                        dispatchGroup.leave()
                    }.failureHandler(on: DispatchQueue.global(qos: .utility)) { _ in
                        dispatchGroup.leave()
                }
                //                XCTAssert(nil == self.networking.perform(.get(from: self.testBaseAddress + "/status/\(code)")).value, "Network responded while should not")
                //                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: DispatchQueue.global(qos: .utility)) {}
        XCTAssert(.success == dispatchGroup.wait(timeout: .now() + 30), "Not in time - possible deadlock or fail")
    }
    
    func testGETRequest() {
        guard let response = networking.perform(.get(from: testBaseAddress + "get")).value else {
            XCTAssert(false, "No response from network!")
            return
        }
        XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
    }
    
    func testPOSTRequest() {
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonRequestDict, options: .prettyPrinted)
        guard let response = networking.perform(.post(data: jsonData, type: .json(encoded: .utf8), to: testBaseAddress + "post")).value else {
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
        XCTAssert(jsonUnwrappedResponse == jsonRequestDict, "Network response don't match request")
    }
    
    func testDownloadRequest() {
        let bytesToDownload = 102400
        var progressRecived = false
        
        let promise = networking.perform(.download(from: testBaseAddress + "bytes/\(bytesToDownload)", savingTo: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("test.data")))
        
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
    }
    
    func testRedirection() {
        var redirectionHandled = false
        networking.redirectionHandler = { session, request in
            redirectionHandled = true
            return request
        }
        guard let response = networking.perform(.get(from: testBaseAddress + "redirect/3")).value else {
            XCTAssert(false, "No response from network!")
            return
        }
        
        XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
        XCTAssert(redirectionHandled, "Redirection not handled")
    }
    
    func testRedirectionCancel() {
        networking.redirectionHandler = { _ in
            return nil
        }
        let response = networking.perform(.get(from: testBaseAddress + "redirect-to?url=httpbin.org/get")).value
        XCTAssert(response == nil, "Redirection cancel not performed")
    }
    
}
