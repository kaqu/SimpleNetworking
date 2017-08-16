//
//  CertificateContainer.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public struct CertificateContainer {
    
    public let containerBundle: Bundle
    
    public let certificates: [SecCertificate]
    
    public init(containerBundle: Bundle = Bundle.main) {
        self.containerBundle = containerBundle
        self.certificates = CertificateContainer.certificates(in: containerBundle)
    }
    
    private static func certificates(in bundle: Bundle = Bundle.main) -> [SecCertificate] {
        var certificates: [SecCertificate] = []
        
        let paths = Set([".cer", ".CER", ".crt", ".CRT", ".der", ".DER"].map { fileExtension in
            bundle.paths(forResourcesOfType: fileExtension, inDirectory: nil)
            }.joined())
        
        for path in paths {
            if let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData,
                let certificate = SecCertificateCreateWithData(nil, certificateData)
            {
                certificates.append(certificate)
            }
        }
        
        return certificates
    }
}
