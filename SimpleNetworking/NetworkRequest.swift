//
//  NetworkRequest.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public struct NetworkRequest {
    
    public enum Method {
        case get
        case post(data: Data)
    }
    
    public enum ContentType {
        case json(encoded: String.Encoding)
    }
    
    let requestURL: URL
    let method: Method
    let contentType: ContentType
    var currentSessionTask: URLSessionTask? = nil
    
    let urlRequest: URLRequest
    public init(_ method: Method = .get, on requestURL: URL, withContentType contentType: ContentType = .json(encoded: .utf8), andCustomHeaders customHeaders: [String:String] = [:]) {
        self.requestURL = requestURL
        self.method = method
        self.contentType = contentType
        self.urlRequest  = {
            var request = URLRequest(url: requestURL)
            request.httpMethod = method.methodString
            let contentTypeHeader = contentType.requestHeaderValue
            var customHeaders = customHeaders
            customHeaders[contentTypeHeader.0] = contentTypeHeader.1
            request.httpBody = method.data
            request.allHTTPHeaderFields = customHeaders
            return request
        } ()
    }
}

extension NetworkRequest : Equatable {
    public static func ==(lhs:NetworkRequest, rhs:NetworkRequest)-> Bool {
        return lhs.requestURL == rhs.requestURL
            && lhs.method == rhs.method
            && lhs.contentType == rhs.contentType
            && lhs.currentSessionTask == rhs.currentSessionTask
    }
}

extension NetworkRequest.Method {
    
    var methodString: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        }
    }
    
    var data: Data? {
        switch self {
        case .get:
            return nil
        case let .post(data):
            return data
        }
    }
}

extension NetworkRequest.Method : Equatable {
    public static func ==(lhs:NetworkRequest.Method, rhs:NetworkRequest.Method)-> Bool {
        if rhs.methodString != lhs.methodString {
            return false
        } else if case .post(let lData) = lhs, case .post(let rData) = rhs {
           return lData == rData
        } else {
            return true
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
            return ""
        }
    }
}

extension NetworkRequest.ContentType : Equatable {
    public static func ==(lhs:NetworkRequest.ContentType, rhs:NetworkRequest.ContentType)-> Bool {
        return lhs.requestHeaderValue == rhs.requestHeaderValue
    }
}
