//
//  URLSession+Combine.swift
//  CombineExamples
//
//  Created by Pawel Krawiec on 18/06/2019.
//  Copyright © 2019 tailec. All rights reserved.
//

import Foundation
import Combine

extension URLSession {
    // 原本的是 Response + Data 的形式, 通过这种变化, 变为了 Data 的形式. 
    func get(url: URL, params: [String: String]) -> AnyPublisher<Data, URLError> {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for param in params {
            request.setValue(param.value, forHTTPHeaderField: param.key)
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .eraseToAnyPublisher()
    }
}
