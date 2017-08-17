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
    
    static let requestQueue: DispatchQueue = DispatchQueue(label: "Networking-Request-Queue", qos: .default, attributes: .concurrent)
    static let responseQueue: DispatchQueue = DispatchQueue(label: "Networking-Response-Queue", qos: .default, attributes: .concurrent)
    
    public init(withTrustedServerCertificates trustedServerCertificates: Dictionary<String,CertificateContainer> = [:]) {
        self.session = URLSession(configuration: .default, delegate: NetworkingDelegate(with:trustedServerCertificates), delegateQueue: nil)
    }
}

extension Networking {
    
    public func perform(_ task: NetworkRequest.Task, with headers: NetworkRequest.Headers = [:], respondingOn respondQueue: DispatchQueue = Networking.responseQueue) -> FailablePromise<NetworkResponse> {
        return perform(NetworkRequest(task, with: headers), respondingOn: respondQueue)
    }
    
    
    public func perform(_ request: NetworkRequest, respondingOn responseQueue: DispatchQueue = Networking.responseQueue) -> FailablePromise<NetworkResponse> {
        
        let responsePromise = FailablePromise<NetworkResponse>()
        
        Networking.requestQueue.async {
            var request = request
            let task = self.session.dataTask(with: request.urlRequest) { (data, response, error) in
                responseQueue.async {
                    if let error = error {
                        responsePromise.send(.fail(with:error))
                    } else if let response = response as? HTTPURLResponse {
                        responsePromise.send(.fulfill(with:NetworkResponse(response: response, data: data)))
                    }
                }
            }
            request.associatedSessionTask = task
            task.resume()
        }
        return responsePromise
    }
}


