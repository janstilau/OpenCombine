//
//  DelegateProxy.swift
//  CombineCocoa
//
//  Created by Joan Disho on 25/09/2019.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Foundation
import Combine

#if canImport(Runtime)
import Runtime
#endif

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
open class DelegateProxy: ObjcDelegateProxy {
    private var dict: [Selector: [([Any]) -> Void]] = [:]
    private var subscribers = [AnySubscriber<[Any], Never>?]()
    
    public required override init() {
        super.init()
    }
    
    public override func triggerInterceptedSelector(_ selector: Selector, arguments: [Any]) {
        dict[selector]?.forEach { handler in
            handler(arguments)
        }
    }
    
    public func collectInterceptSelAndHandler(_ selector: Selector, _ handler: @escaping ([Any]) -> Void) {
        if dict[selector] != nil {
            dict[selector]?.append(handler)
        } else {
            dict[selector] = [handler]
        }
    }
    
    public func interceptSelectorPublisher(_ selector: Selector) -> AnyPublisher<[Any], Never> {
        // DelegateProxyPublisher 的构造方法, 其实是当做了工具方法.
        // 目的就是在于, 将 Subscriber 进行存储.
        DelegateProxyPublisher<[Any]> { subscriber in
            self.subscribers.append(subscriber)
            return self.collectInterceptSelAndHandler(selector) { args in
                _ = subscriber.receive(args)
            }
        }.eraseToAnyPublisher()
    }
    
    // DelegateProxy 这个对象, 是和 Obj 进行挂钩的. 如果 Obj 消失了, 这里的 Deinit 也就会被触发.
    deinit {
        subscribers.forEach { $0?.receive(completion: .finished) }
        subscribers = []
        self.dict = [:]
    }
}
#endif
