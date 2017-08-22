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
        case download(from: String, savingTo: URL)
//        case downloadWithoutSaving(from: String)
//        case upload(data: Data, to: String)
    }
    
    public enum ContentType {
        case json(encoded: String.Encoding)
    }
    
    public typealias Headers = [String:String]
    
    public let urlRequest: URLRequest
    public let task: Task
    internal var associatedSessionTask: URLSessionTask? = nil
    internal weak var responsePromise: FailablePromise<NetworkResponse>?
    
    public init(_ task: Task, with headers: NetworkRequest.Headers = [:]) {
        self.task = task
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
    
    static func authorizationHeader(user: String, password: String) -> (key: String, value: String)? {
        guard let data = "\(user):\(password)".data(using: .utf8) else { return nil }
        
        let credential = data.base64EncodedString(options: [])
        
        return (key: "Authorization", value: "Basic \(credential)")
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
        case let .download(address, _):
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
        case .download:
            return "GET"
        }
    }
    
    var sentData: Data? {
        switch self {
        case .get:
            return nil
        case let .post(data, _, _):
            return data
        case .download:
            return nil
        }
    }
    
    var contentType: NetworkRequest.ContentType? {
        switch self {
        case .get:
            return nil
        case let .post(_, contentType, _):
            return contentType
        case .download:
            return nil
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
