//
//  CertificatePinningTest.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 19/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import XCTest
@testable import SimpleNetworking

class CertificatePinningTest: XCTestCase {
    
    var testSemaphore = DispatchSemaphore(value: 0)
    var testQueue = DispatchQueue(label: "TestQueue")
    let responseDefaultWaitTime = 5 as Double
    
    let testPinnedBaseAddress = "https://httpbin.org/"
    let testNotPinnedBaseAddress = "https://google.com/"
    var networking = Networking()
    let jsonRequestDict = ["test":"test"]
    
    override func setUp() {
        super.setUp()
        networking = Networking(withTrustedServerCertificates: [PinningCertificateContainer(for: ["(.)*httpbin\\.org"], fromBundle: Bundle.init(for: CertificatePinningTest.self))])
        testSemaphore = DispatchSemaphore(value: 0)
        testQueue = DispatchQueue(label: "TestQueue")
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
    
    func testGETPinnedRequest() {
        testQueue.async {
            guard let response = self.networking.perform(.get(from: self.testPinnedBaseAddress + "get")).value else {
                XCTAssert(false, "No response from network!")
                return
            }
            XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testGETPinnedFailRequest() {
        testQueue.async {
            XCTAssert(self.networking.perform(.get(from: self.testNotPinnedBaseAddress)).value == nil, "Network response when pinning should cut off")
            self.testSemaphore.signal()
        }
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testPOSTPinnedRequest() {
        testQueue.async {
            let jsonData = try! JSONSerialization.data(withJSONObject: self.jsonRequestDict, options: .prettyPrinted)
            guard let response = self.networking.perform(.post(data: jsonData, type: .json(encoded: .utf8), to: self.testPinnedBaseAddress + "post")).value else {
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
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
    
    func testDownloadPinnedRequest() {
        testQueue.async {
            let bytesToDownload = 102400
            var progressRecived = false
            
            let promise = self.networking.perform(.download(from: self.testPinnedBaseAddress + "bytes/\(bytesToDownload)", savingTo: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("test.data")))
            
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
        XCTAssert(.success == testSemaphore.wait(timeout: .now() + responseDefaultWaitTime), "Not in time - possible deadlock or fail")
    }
}
