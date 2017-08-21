//
//  NetworkingDelegate.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

internal class NetworkingDelegate : NSObject  {
    
    fileprivate static let validHTTPCodes = 200..<400
    
    internal var validateResponseStatusCodes: Bool = false
    
    let trustedServerCertificates: [PinningCertificateContainer]
    
    internal var pendingRequests = [Int:NetworkRequest]()
    
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
        
        guard nil == redirectedRequest else {
            return
        }
        
        task.cancel()
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // TODO: to complete - app background events
    }
}

extension NetworkingDelegate : URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let request = pendingRequests[task.taskIdentifier] else {
            return
        }
        defer {
            pendingRequests[task.taskIdentifier] = nil
        }
        
        if let error = error {
            request.responsePromise?.send(.fail(with:error))
        } else if let response = task.response as? HTTPURLResponse {
            if validateResponseStatusCodes, !(NetworkingDelegate.validHTTPCodes).contains(response.statusCode) {
                request.responsePromise?.send(.fail(with:Networking.Error.statusCode(response.statusCode)))
            } else {
                request.responsePromise?.send(.fulfill(with:NetworkResponse(response: response, data: nil)))
            }
        } else {
            request.responsePromise?.send(.fail(with:Networking.Error.noErrorOrResponse))
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        urlSession(session, didReceive: challenge, completionHandler: completionHandler) // TODO: to check
    }
}

extension NetworkingDelegate : URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

        guard let request = pendingRequests[dataTask.taskIdentifier] else {
            return
        }
        defer {
            pendingRequests[dataTask.taskIdentifier] = nil
        }
        
        if let response = dataTask.response as? HTTPURLResponse {
            if validateResponseStatusCodes, !(NetworkingDelegate.validHTTPCodes).contains(response.statusCode) {
                request.responsePromise?.send(.fail(with:Networking.Error.statusCode(response.statusCode)))
            } else {
                request.responsePromise?.send(.fulfill(with:NetworkResponse(response: response, data: data)))
            }
        }
    }
}

extension NetworkingDelegate : URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        // TODO: to complete
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        guard let downloadRequest = pendingRequests[downloadTask.taskIdentifier] else {
            return
        }
        
        guard case let .download(_, destination) = downloadRequest.task else {
            return
        }
        
        defer {
            pendingRequests[downloadTask.taskIdentifier] = nil
        }
        
        do {
            try Data(contentsOf: location).write(to: destination, options: .atomicWrite)
        } catch {
            downloadRequest.responsePromise?.send(.fail(with:error))
            return
        }
        
        guard let response = downloadTask.response as? HTTPURLResponse else {
            return
        }
        do {
            let data = try Data(contentsOf: destination)
            downloadRequest.responsePromise?.send(.fulfill(with:NetworkResponse(response: response, data: data)))
        } catch {
            downloadRequest.responsePromise?.send(.fail(with:error))
        }
    }
    
    @objc public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard let downloadRequest = pendingRequests[downloadTask.taskIdentifier] else {
            return
        }
        
        let progressValue = Progress(totalUnitCount: totalBytesExpectedToWrite)
        progressValue.completedUnitCount = totalBytesWritten
        downloadRequest.responsePromise?.send(.progress(value: progressValue))
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
