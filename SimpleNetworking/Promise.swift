//
//  Promise.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 26/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public protocol Promise {
    
    associatedtype PromiseType
    
    var value: PromiseType? { get }
}
