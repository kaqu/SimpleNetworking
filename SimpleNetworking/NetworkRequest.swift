//
//  NetworkRequest.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public struct NetworkRequest {
    
    public enum Task {
        case get(from: String)
        case post(data: Data, type: NetworkRequest.ContentType, to: String)
//        case .download(from:String)
    }
    
    public enum ContentType {
        case json(encoded: String.Encoding)
    }
    
    public typealias Headers = [String:String]
    
    public let urlRequest: URLRequest
    internal var associatedSessionTask: URLSessionTask? = nil
    
    public init(_ task: Task, with headers: NetworkRequest.Headers = [:]) {
        self.urlRequest = {
            var request = URLRequest(url: task.url)
            request.httpMethod = task.methodName
            var customHeaders = headers
            if let contentTypeHeader = task.contentType?.requestHeaderValue {
                customHeaders[contentTypeHeader.0] = contentTypeHeader.1
            }
            request.httpBody = task.sentData
            request.allHTTPHeaderFields = customHeaders
            return request
        } ()
    }
}

extension NetworkRequest.Task {
    
    var url: URL {
        switch self {
        case let .get(address):
            guard let url = URL(string: address) else {
                fatalError("Wrong url: \(address)")
            }
            return url
        case let .post(_, _, address):
            guard let url = URL(string: address) else {
                fatalError("Wrong url: \(address)")
            }
            return url
        }
    }
    
    var methodName: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        }
    }
    
    var sentData: Data? {
        switch self {
        case .get:
            return nil
        case let .post(data, _, _):
            return data
        }
    }
    
    var contentType: NetworkRequest.ContentType? {
        switch self {
        case .get:
            return nil
        case let .post(_, contentType, _):
            return contentType
        }
    }
}

extension NetworkRequest.ContentType {
    
    var requestHeaderValue: (String, String) {
        switch self {
        case let .json(encoding):
            return ("Content-Type","application/json\(headerStringForEncoding(encoding))")
        }
    }
    
    func headerStringForEncoding(_ encoding: String.Encoding) -> String {
        if .utf8 == encoding {
            return "; charset=utf-8"
        } else {
            fatalError("Unsupported character encoding")
        }
    }
}
