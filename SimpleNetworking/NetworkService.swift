//
//  NetworkService.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 18/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public protocol NetworkService {
    
    var path: String { get }
    
    var task: NetworkEndpoint.Task { get }
    
    var headers: NetworkRequest.Headers { get }
}
