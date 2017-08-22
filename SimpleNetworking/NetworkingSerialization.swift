//
//  NetworkingSerialization.swift
//  SimpleNetworking
//
//  Created by Kacper Kaliński on 22/08/2017.
//  Copyright © 2017 Kacper Kaliński. All rights reserved.
//

import Foundation

public extension Encodable {

    func jsonData() throws -> Data {
        return try Networking.jsonEncoder.encode(self)
    }
}

public extension FailablePromise where PromiseType == NetworkResponse {
    
    func jsonTransform<DecodedType: Decodable>(to decodeType: DecodedType.Type) -> FailablePromise<DecodedType> {
        return FailablePromise<DecodedType>(transforming: self, with: { response in
            guard let data = response.data else {
                return .failure(reason: Networking.Error.noData)
            }
            guard let decoded = try? JSONDecoder().decode(DecodedType.self, from: data) else {
                return .failure(reason: Networking.Error.invalidResponse)
            }
            return .success(with: decoded)
        })
    }
}
