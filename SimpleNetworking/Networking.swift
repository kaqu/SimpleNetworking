//
//  Networking.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public final class Networking {
    
    public static let `default`: Networking = {
        return Networking()
    }()
    
    public let session: URLSession
    internal let delegate: NetworkingDelegate
    
    static let requestQueue: DispatchQueue = DispatchQueue(label: "Networking-RequestQueue", qos: .default, attributes: .concurrent)
    static let jsonEncoder = JSONEncoder()
    static let jsonDecoder = JSONDecoder()
    
    public init(withTrustedServerCertificates trustedServerCertificates: [PinningCertificateContainer] = []) {
        self.delegate = NetworkingDelegate(with:trustedServerCertificates)
        let sessionConfiguration = URLSessionConfiguration.default
        self.session = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
    }
    
    public enum Error : Swift.Error {
        case noErrorOrResponse
        case invalidResponse
        case noData
        case cancelled
        case statusCode(Int)
    }
}

extension Networking {
    
    public func perform(_ task: NetworkRequest.Task, with headers: NetworkRequest.Headers = [:]) -> FailablePromise<NetworkResponse> {
        return perform(request: NetworkRequest(task, with: headers))
    }
    
    public func perform(request: NetworkRequest) -> FailablePromise<NetworkResponse> {
        
        let responsePromise = FailablePromise<NetworkResponse>()
        Networking.requestQueue.async {
            var request = request
            request.responsePromise = responsePromise
            let task: URLSessionTask
            if case .download = request.task {
                task = self.session.downloadTask(with: request.urlRequest)
            } else {
                task = self.session.dataTask(with: request.urlRequest)
            }
            request.associatedSessionTask = task
            self.delegate.pendingRequests[task.taskIdentifier] = request
            task.resume()
        }
        return responsePromise
    }
}

extension Networking {
    
    public var redirectionHandler: ((HTTPURLResponse, URLRequest)->URLRequest?)? {
        get {
            return delegate.redirectionHandler
        }
        set {
            delegate.redirectionHandler = newValue
        }
    }
    
    public func withRedirectionHandler(_ handler: ((HTTPURLResponse, URLRequest)->URLRequest?)?) -> Self {
        delegate.redirectionHandler = handler
        return self
    }
    
    public var sessionInvalidationHandler: ((Swift.Error?)->())? {
        get {
            return delegate.sessionInvalidationHandler
        }
        set {
            delegate.sessionInvalidationHandler = newValue
        }
    }
    
    public func withSessionInvalidationHandler(_ handler: ((Swift.Error?)->())?) -> Self {
        delegate.sessionInvalidationHandler = handler
        return self
    }
    
    public var validateResponseStatusCodes: Bool {
        get {
            return delegate.validateResponseStatusCodes
        }
        set {
            delegate.validateResponseStatusCodes = newValue
        }
    }
    
    public func withResponseStatusCodeValidation(_ validate: Bool) -> Self {
        delegate.validateResponseStatusCodes = validate
        return self
    }
}

