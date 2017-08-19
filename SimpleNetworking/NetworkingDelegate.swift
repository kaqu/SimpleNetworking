//
//  NetworkingDelegate.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

internal class NetworkingDelegate : NSObject  {
    
    let trustedServerCertificates: [PinningCertificateContainer]
    
    internal var pendingRequests = [NetworkRequest]()
    
    internal var redirectionHandler: ((HTTPURLResponse, URLRequest)->URLRequest?)?
    internal var sessionInvalidationHandler: ((Error?)->())?
    
    init(with trustedServerCertificates: [PinningCertificateContainer]) {
        self.trustedServerCertificates = trustedServerCertificates
        super.init()
    }
}

extension NetworkingDelegate : URLSessionDelegate {
    
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
            guard let trustedCertificatesForHost = trustedServerCertificates.first(where: { $0.isAssociatedWith(host:host) })?.certificates else { return }
            // TODO: if host matches more than one certificate container certs should be merged
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
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        guard let handler = sessionInvalidationHandler else {
            return
        }
        handler(error)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        
        var redirectedRequest: URLRequest? = request
        
        defer {
            completionHandler(redirectedRequest)
        }
        
        guard let handler = redirectionHandler else {
            return
        }
        
        redirectedRequest = handler(response, request)
    }
}

extension NetworkingDelegate : URLSessionTaskDelegate {
    
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        // TODO: upload progress
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let finishedRequestIndex = pendingRequests.index(where: { $0.associatedSessionTask == task }) else {
            return
        }
        pendingRequests.remove(at: finishedRequestIndex)
    }
}

extension NetworkingDelegate : URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let request = pendingRequests.first(where: { $0.associatedSessionTask == dataTask } ) else {
            return
        }
        
        Networking.responseQueue.async {
            if let response = dataTask.response as? HTTPURLResponse {
                request.responsePromise?.send(.fulfill(with:NetworkResponse(response: response, data: data)))
            } else {
                fatalError("Lazy programmist") //TODO: FIXME: to complete
                //                responsePromise.send(.fail(with:Error.noErrorOrResponse))
            }
        }
    }
}

extension NetworkingDelegate : URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        // TODO: to complete
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        guard let downloadRequest = pendingRequests.first(where: { $0.associatedSessionTask == downloadTask } ) else {
            return
        }
        
        guard case let .download(_, destination) = downloadRequest.task else {
            return
        }
        
        do {
            try Data(contentsOf: location).write(to: destination, options: .atomicWrite)
        } catch {
            Networking.responseQueue.async {
                downloadRequest.responsePromise?.send(.fail(with:error))
            }
            return
        }
        
        Networking.responseQueue.async {
            guard let response = downloadTask.response as? HTTPURLResponse else {
                downloadRequest.responsePromise?.send(.fail(with:Networking.Error.invalidResponse))
                return
            }
            do {
                let data = try Data(contentsOf: destination)
                downloadRequest.responsePromise?.send(.fulfill(with:NetworkResponse(response: response, data: data)))
            } catch {
                downloadRequest.responsePromise?.send(.fail(with:error))
            }
        }
    }
    
    @objc public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard let downloadRequest = pendingRequests.first(where: { $0.associatedSessionTask == downloadTask } ) else {
            return
        }
        let progressValue = Progress(totalUnitCount: 0)
        progressValue.totalUnitCount = totalBytesExpectedToWrite
        progressValue.completedUnitCount = totalBytesWritten
        Networking.responseQueue.async {
            downloadRequest.responsePromise?.send(.progress(value: progressValue))
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
