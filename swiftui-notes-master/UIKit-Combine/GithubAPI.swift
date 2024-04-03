//
//  GithubAPI.swift
//  UIKit-Combine
//
//  Created by Joseph Heck on 7/13/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import Foundation

enum APIFailureCondition: Error {
    case invalidServerResponse
}

struct GithubAPIUser: Decodable {
    // A very *small* subset of the content available about
    //  a github API user for example:
    // https://api.github.com/users/heckj
    let login: String
    let public_repos: Int
    let avatar_url: String
}

// 这其实应该算作是 ViewModel 里面的状态, 只不过作者在这, 使用了一个比较简单的方式而已.
enum GithubAPI {
    
    // 当 ViewModel, 真正的进行网络请求的时候, 发出对应的 Loading 信号, 触发 View 层的改变.
    static let networkActivityPublisher = PassthroughSubject<Bool, Never>()
    
    /// creates a one-shot publisher that provides a GithubAPI User
    /// object as the end result. This method was specifically designed to
    /// return a list of 1 object, as opposed to the object itself to make
    /// it easier to distinguish a "no user" result (empty list)
    /// representation that could be dealt with more easily in a Combine
    /// pipeline than an optional value. The expected return types is a
    /// Publisher that returns either an empty list, or a list of one
    /// GithubAPUser, and with a failure return type of Never, so it's
    /// suitable for recurring pipeline updates working with a @Published
    /// data source.
    /*
     创建一个一次性的发布者，提供 GithubAPI 用户对象作为最终结果。此方法专门设计为返回一个对象列表，而不是对象本身，以便更容易区分“无用户”结果（空列表）的表示，这样可以更轻松地在 Combine 流水线中处理，而不是使用可选值。预期的返回类型是一个发布者，它返回一个空列表或一个包含一个 GithubAPUser 的列表，并且具有 Never 的失败返回类型，因此适用于使用 @Published 数据源进行循环流水线更新。
     */
    // View Model 的内部, 进行网络请求的接口.
    static func retrieveGithubUser(username: String) -> AnyPublisher<[GithubAPIUser], Never> {
        if username.count < 3 {
            // 如果数据不对, 直接就返回一个空对象.
            // just 在这种, 明确的使用默认值的时候, 非常常用.
            return Just([]).eraseToAnyPublisher()
            // return Publishers.Empty<GithubAPIUser, Never>()
            //    .eraseToAnyPublisher()
        }
        let assembledURL = String("https://api.github.com/users/\(username)")
        let publisher = URLSession.shared.dataTaskPublisher(for: URL(string: assembledURL)!)
        // 使用 handleEvents 的副作用的模式, 完成了 Loading 状态信号的改变.
            .handleEvents(receiveSubscription: { _ in
                networkActivityPublisher.send(true)
            }, receiveCompletion: { _ in
                networkActivityPublisher.send(false)
            }, receiveCancel: {
                networkActivityPublisher.send(false)
            })
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200
                else {
                    throw APIFailureCondition.invalidServerResponse
                }
                return data
            }
            .decode(type: GithubAPIUser.self, decoder: JSONDecoder())
            .map {
                [$0]
            }
        // Replaces any errors in the stream with the provided element.
        /*
         If the upstream publisher fails with an error, this publisher emits the provided element, then finishes normally.
         This replaceError(with:) functionality is useful when you want to handle an error by sending a single replacement element and end the stream. Use catch(_:) to recover from an error and provide a replacement publisher to continue providing elements to the downstream subscriber.
         */
            .replaceError(with: [])
            .eraseToAnyPublisher()
        return publisher
    }
}
