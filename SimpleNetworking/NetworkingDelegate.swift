//
//  NetworkingDelegate.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

internal final class NetworkingDelegate : NSObject, URLSessionDelegate {
    
    let trustedServerCertificates: Dictionary<String,CertificateContainer>
    
    init(with trustedServerCertificates: Dictionary<String,CertificateContainer>) {
        self.trustedServerCertificates = trustedServerCertificates
        super.init()
    }
}

extension NetworkingDelegate {
    
    public var pinCertificatesEnabled: Bool {
        return trustedServerCertificates.count > 0
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        
        var disposition: URLSession.AuthChallengeDisposition = .cancelAuthenticationChallenge
        var credential: URLCredential? = nil
        
        defer {
            completionHandler(disposition, credential)
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return
        }
        
        let host = challenge.protectionSpace.host
        
        let policy = SecPolicyCreateSSL(true, host as CFString)
        
        SecTrustSetPolicies(serverTrust, policy)
        
        if pinCertificatesEnabled {
            guard let trustedCertificatesForHost = trustedServerCertificates[host]?.certificates else { return }
            
//            let serverCertificatesDataArray = serverTrust.certificates.map { SecCertificateCopyData($0) as Data }
//            let trustedCertificatesDataArray = trustedCertificatesForHost.map { SecCertificateCopyData($0) as Data }
//            
//            for serverCertificateData in serverCertificatesDataArray {
//                    if trustedCertificatesDataArray.contains(serverCertificateData) {
//                        disposition = .useCredential
//                        credential = URLCredential(trust:serverTrust)
//                        return
//                }
//            }
            
                        SecTrustSetAnchorCertificates(serverTrust, trustedCertificatesForHost as CFArray)
                        SecTrustSetAnchorCertificatesOnly(serverTrust, true)
        }
        
        if serverTrust.isValid {
            disposition = .useCredential
            credential = URLCredential(trust:serverTrust)
        } else {
            disposition = .cancelAuthenticationChallenge
        }
    }
    
}

extension SecTrust {
    
    var certificates: [SecCertificate] {
        var certificates: [SecCertificate] = []
        
        let certificateCount = SecTrustGetCertificateCount(self)
        
        guard certificateCount > 0 else {
            return certificates
        }
        
        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(self, i) else { continue }
            certificates.append(certificate)
        }
        
        return certificates
    }
    
    var isValid: Bool {
        var isValid = false
        
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(self, &result)
        
        if status == errSecSuccess {
            let unspecified = SecTrustResultType.unspecified
            let proceed = SecTrustResultType.proceed
            
            
            isValid = result == unspecified || result == proceed
        }
        
        return isValid
    }
}
