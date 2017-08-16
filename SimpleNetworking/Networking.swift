//
//  Networking.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public class Networking : NSObject, URLSessionDelegate {
    
    private(set) var session: URLSession = URLSession.shared
    
    let trustedServerCertificates: Dictionary<String,CertificateContainer>
    
    var pendingRequests: [String:NetworkRequest] = [:]
    
    let networkingQueue: DispatchQueue = DispatchQueue(label: "Networking", qos: .default, attributes: .concurrent)
    
    public init(withTrustedServerCertificates trustedServerCertificates: Dictionary<String,CertificateContainer> = [:]) {
        self.trustedServerCertificates = trustedServerCertificates
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        
    }
}

extension Networking {
    
    public var pinCertificatesEnabled: Bool {
        return trustedServerCertificates.count > 0
    }
    
    public func perform(_ request: NetworkRequest, respondingOn respondQueue: DispatchQueue = .main) {
        networkingQueue.async {
            var request = request
            let uniqueRequestID = "TODO:!" // TODO: FIXME: !
            let task = self.session.dataTask(with: request.urlRequest) { (data, response, error) in
                self.pendingRequests[uniqueRequestID] = nil
                // TODO: to complete
                respondQueue.async {
                    // TODO: to complete
                    print("Responded")
                    print(response)
                    print(error)
                }
            }
            request.currentSessionTask = task
            self.pendingRequests[uniqueRequestID] = request
            task.resume()
        }
    }
}


extension Networking {
    
    
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
        print(host)
        print(trustedServerCertificates)
        SecTrustSetPolicies(serverTrust, policy)
        
        if pinCertificatesEnabled {
            guard let trustedCertificatesForHost = trustedServerCertificates[host]?.certificates else { print("escape early");return }
            
            let serverCertificatesDataArray = serverTrust.certificates.map { SecCertificateCopyData($0) as Data }
            let trustedCertificatesDataArray = trustedCertificatesForHost.map { SecCertificateCopyData($0) as Data }
            
            for serverCertificateData in serverCertificatesDataArray {
                for pinnedCertificateData in trustedCertificatesDataArray {
                    if serverCertificateData == pinnedCertificateData {
                        disposition = .useCredential
                        credential = URLCredential(trust:serverTrust)
                        return
                    }
                }
            }
            
//            SecTrustSetAnchorCertificates(serverTrust, trustedCertificatesForHost as CFArray)
//            SecTrustSetAnchorCertificatesOnly(serverTrust, true)
        }
        
        if serverTrust.isValid {
            disposition = .useCredential
            credential = URLCredential(trust:serverTrust)
        } else {
            disposition = .cancelAuthenticationChallenge
        }
        
        //        for certificate in trust.certificates {
        //            if trustedCertificates[host]?.holdedCertificates.contains(certificate) ?? false { // TODO: to complete - allow connections without pinning
        //                disposition = .useCredential
        //                credential = URLCredential(trust:trust)
        //                return
        //            }
        //        }
        //
        /*
         SecTrustSetPolicies(serverTrust, policy)
         
         SecTrustSetAnchorCertificates(serverTrust, pinnedCertificates as CFArray)
         SecTrustSetAnchorCertificatesOnly(serverTrust, true)
         
         private func trustIsValid(_ trust: SecTrust) -> Bool {
         var isValid = false
         
         var result = SecTrustResultType.invalid
         let status = SecTrustEvaluate(trust, &result)
         
         if status == errSecSuccess {
         let unspecified = SecTrustResultType.unspecified
         let proceed = SecTrustResultType.proceed
         
         
         isValid = result == unspecified || result == proceed
         }
         
         return isValid
         }
         
         
         if validateCertificateChain {
         let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
         SecTrustSetPolicies(serverTrust, policy)
         
         SecTrustSetAnchorCertificates(serverTrust, pinnedCertificates as CFArray)
         SecTrustSetAnchorCertificatesOnly(serverTrust, true)
         
         serverTrustIsValid = trustIsValid(serverTrust)
         } else {
         let serverCertificatesDataArray = certificateData(for: serverTrust)
         let pinnedCertificatesDataArray = certificateData(for: pinnedCertificates)
         
         outerLoop: for serverCertificateData in serverCertificatesDataArray {
         for pinnedCertificateData in pinnedCertificatesDataArray {
         if serverCertificateData == pinnedCertificateData {
         serverTrustIsValid = true
         break outerLoop
         }
         }
         }
         }
         */
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
