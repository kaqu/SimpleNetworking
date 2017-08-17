//
//  NetworkResponse.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 16/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public struct NetworkResponse {
    
    public let response: HTTPURLResponse
    public let data: Data?

    var statusCode: Int {
        return response.statusCode
    }
    
    var headers: [AnyHashable : Any] {
        return response.allHeaderFields
    }
}
