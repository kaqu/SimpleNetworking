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
    
    let testPinnedBaseAddress = "https://httpbin.org/"
    let testNotPinnedBaseAddress = "https://google.com/"
    var networking = Networking()
    let jsonRequestDict = ["test":"test"]
    
    override func setUp() {
        super.setUp()
        networking = Networking(withTrustedServerCertificates: [PinningCertificateContainer(for: ["(.)*httpbin\\.org"], fromBundle: Bundle.init(for: CertificatePinningTest.self))])
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
    
    func testGETPinnedRequest() {
        guard let response = networking.perform(.get(from: testPinnedBaseAddress + "get")).value else {
            XCTAssert(false, "No response from network!")
            return
        }
        XCTAssert(response.statusCode == 200, "Network response not OK - status: \(response.statusCode)")
    }
    
    func testGETPinnedFailRequest() {
        XCTAssert(networking.perform(.get(from: testNotPinnedBaseAddress)).value == nil, "Network response when pinning should cut off")
    }
    
    func testPOSTPinnedRequest() {
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonRequestDict, options: .prettyPrinted)
        guard let response = networking.perform(.post(data: jsonData, type: .json(encoded: .utf8), to: testPinnedBaseAddress + "post")).value else {
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
    
    func testDownloadPinnedRequest() {
        let bytesToDownload = 102400
        var progressRecived = false
        
        let promise = networking.perform(.download(from: testPinnedBaseAddress + "bytes/\(bytesToDownload)", savingTo: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("test.data")))
        
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
}
