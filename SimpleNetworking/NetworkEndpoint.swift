//
//  NetworkEndpoint.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 19/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public struct NetworkEndpoint {
    
    public let basePath: String
    
    public let networking: Networking
    
    public init(at basePath: String, using networking: Networking = Networking.default) {
        self.basePath = basePath
        self.networking = networking
    }
    
    public enum Task {
        case get
        case post(data: Data, contentType: NetworkRequest.ContentType)
        case download(to: URL)
        // case upload
    }
}

extension NetworkEndpoint {
    
    public func fullServicePath(_ service: NetworkService) -> String {
        return basePath.appending("\(service.path)")
    }
    
    public func call(_ service: NetworkService/*, respondingOn responseQueue: DispatchQueue = Networking.responseQueue*/) -> FailablePromise<NetworkResponse> {
        switch service.task {
        case .get:
            return networking.perform(.get(from: fullServicePath(service)), with: service.headers/*, respondingOn: responseQueue*/)
        case let .post(data, contentType):
            return networking.perform(.post(data: data, type: contentType, to: fullServicePath(service)), with: service.headers/*, respondingOn: responseQueue*/)
        case let .download(destination):
            return networking.perform(.download(from: fullServicePath(service), savingTo: destination), with: service.headers/*, respondingOn: responseQueue*/)
        }
    }
}
