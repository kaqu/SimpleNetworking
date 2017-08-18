//
//  PinningCertificateContainer.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 18/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation


public struct PinningCertificateContainer {
    
    public typealias RegexString = String
    
    public let certificates: [SecCertificate]
    
    public let associatedHosts: [RegexString]
    
    public init(for associatedHosts: [RegexString], fromBundle containerBundle: Bundle = Bundle.main) {
        self.associatedHosts = associatedHosts
        self.certificates = getCertificates(from: containerBundle)
    }
}

extension PinningCertificateContainer {
    
    public func isAssociatedWith(host: String) -> Bool {
        for pattern in associatedHosts {
            if let _ = host.range(of: pattern, options: .regularExpression) {
                return true
            }
        }
        return false
        
    }
}
