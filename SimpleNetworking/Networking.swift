//
//  Networking.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public final class Networking {
    
    let session: URLSession
    let delegate: NetworkingDelegate
    
    static let requestQueue: DispatchQueue = DispatchQueue(label: "Networking-Request-Queue", qos: .default, attributes: .concurrent)
    static let responseQueue: DispatchQueue = DispatchQueue(label: "Networking-Response-Queue", qos: .default, attributes: .concurrent)
    
    public init(withTrustedServerCertificates trustedServerCertificates: [PinningCertificateContainer] = []) {
        self.delegate = NetworkingDelegate(with:trustedServerCertificates)
        let sessionConfiguration = URLSessionConfiguration.default
        self.session = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
    }
    
    public enum Error : Swift.Error {
        case noErrorOrResponse
    }
}

extension Networking {
    
    public func perform(_ task: NetworkRequest.Task, with headers: NetworkRequest.Headers = [:], respondingOn respondQueue: DispatchQueue = Networking.responseQueue) -> FailablePromise<NetworkResponse> {
        return perform(request: NetworkRequest(task, with: headers), respondingOn: respondQueue)
    }
    
    
    public func perform(request: NetworkRequest, respondingOn responseQueue: DispatchQueue = Networking.responseQueue) -> FailablePromise<NetworkResponse> {
        
        let responsePromise = FailablePromise<NetworkResponse>()
        Networking.requestQueue.async {
            var request = request
            request.responsePromise = responsePromise
            let task: URLSessionTask
            if case .download = request.task {
                task = self.session.downloadTask(with: request.urlRequest)
                /*
                 { (url, response, error) in
                 responseQueue.async {
                 if let error = error {
                 responsePromise.send(.fail(with:error))
                 } else if let response = response as? HTTPURLResponse, let url = url, let data = try? Data(contentsOf: url) {
                 responsePromise.send(.fulfill(with:NetworkResponse(response: response, data: data)))
                 } else {
                 responsePromise.send(.fail(with:Error.noErrorOrResponse))
                 }
                 }
                 }
                 */
            } else {
                task = self.session.dataTask(with: request.urlRequest) { (data, response, error) in
                    responseQueue.async {
                        if let error = error {
                            responsePromise.send(.fail(with:error))
                        } else if let response = response as? HTTPURLResponse {
                            responsePromise.send(.fulfill(with:NetworkResponse(response: response, data: data)))
                        } else {
                            responsePromise.send(.fail(with:Error.noErrorOrResponse))
                    }
                    }
                }
            }
            request.associatedSessionTask = task
            self.delegate.pendingRequests.append(request)
            task.resume()
        }
        return responsePromise
    }
}


