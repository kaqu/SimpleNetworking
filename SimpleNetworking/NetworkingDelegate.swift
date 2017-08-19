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
        if let error = error, let failedRequest = pendingRequests.first(where: { $0.associatedSessionTask == task }) {
            Networking.responseQueue.async {
                failedRequest.responsePromise?.send(.fail(with:error))
            }
        }
        guard let finishedRequestIndex = pendingRequests.index(where: { $0.associatedSessionTask == task }) else {
            return
        }
        pendingRequests.remove(at: finishedRequestIndex)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        urlSession(session, didReceive: challenge, completionHandler: completionHandler) // TODO: to check
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        defer {
            completionHandler(.allow)
        }
        guard let response = response as? HTTPURLResponse else {
            return
        }
        
        guard !(200..<400).contains(response.statusCode) else {
            return
        }
        
        guard let request = pendingRequests.first(where: { $0.associatedSessionTask == dataTask } ) else {
            return
        }
        print(response.statusCode)
        Networking.responseQueue.async {
            request.responsePromise?.send(.fail(with:Networking.Error.statusCode(response.statusCode)))
        }
        
    }
}

extension NetworkingDelegate : URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard dataTask.state == .running else {
            return
        }
        
        guard let request = pendingRequests.first(where: { $0.associatedSessionTask == dataTask } ) else {
            return
        }
        
        Networking.responseQueue.async {
            if let response = dataTask.response as? HTTPURLResponse {
                request.responsePromise?.send(.fulfill(with:NetworkResponse(response: response, data: data)))
            } else {
                request.responsePromise?.send(.fail(with:Networking.Error.invalidResponse))
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
        let progressValue = Progress(totalUnitCount: totalBytesExpectedToWrite)
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
