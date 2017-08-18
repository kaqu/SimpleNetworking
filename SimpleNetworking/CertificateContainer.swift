//
//  CertificateContainer.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public protocol CertificateContainer {
    
    var certificates: [SecCertificate] { get }
}

internal func getCertificates(from bundle: Bundle = Bundle.main) -> [SecCertificate] {
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
