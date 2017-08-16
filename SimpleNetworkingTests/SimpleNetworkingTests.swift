//
//  SimpleNetworkingTests.swift
//  SimpleNetworkingTests
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import XCTest
@testable import SimpleNetworking

class SimpleNetworkingTests: XCTestCase {
    
    var networking = Networking()
    
    override func setUp() {
        super.setUp()
        networking = Networking()
    }
    
    override func tearDown() {
        
        super.tearDown()
    }
    
    func testGetRequestNoPinning() {
        
    }
    
    func testGetRequestWithPinning() {
        
    }
    
    func testPOSTRequestNoPinning() {
        
    }
    
    func testPOSTRequestWithPinning() {
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
