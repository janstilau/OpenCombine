//
//  DelegateProxyPublisher.swift
//  CombineCocoa
//
//  Created by Joan Disho on 25/09/2019.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Foundation
import Combine

// 只会是起始节点. 不会是 Operator 的中间节点.
@available(iOS 13.0, *)
internal class DelegateProxyPublisher<Output>: Publisher {
    typealias Failure = Never
    
    private let handler: (AnySubscriber<Output, Failure>) -> Void
    
    init(_ handler: @escaping (AnySubscriber<Output, Failure>) -> Void) {
        self.handler = handler
    }
    
    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = Subscription(subscriber: AnySubscriber(subscriber), handler: handler)
        subscriber.receive(subscription: subscription)
    }
}

// 这个 Subscription, 不是传统意义上的节点. 是一个包装类型.
// 它的构造函数的触发, 就是进行首节点的创建工作.
// 充分的证明了, 什么叫做, 面向协议编程.
// 这里的 Publisher, 以及 Publisher.Subscription, 都是假象. 仅仅是在 Attach 的时候, 去操作 ObjectDelegate PublisherManager 的相关数据.
// Publisher 就是做的 Subscriber 的 Attach 的工作, 只要能够满足这个要求就可以了. 
@available(iOS 13.0, *)
private extension DelegateProxyPublisher {
    class Subscription<S>: Combine.Subscription where S: Subscriber, Failure == S.Failure, Output == S.Input {
        private var subscriber: S?
        
        init(subscriber: S, handler: @escaping (S) -> Void) {
            self.subscriber = subscriber
            handler(subscriber)
        }
        
        func request(_ demand: Subscribers.Demand) {
            // We don't care for the demand.
        }
        
        func cancel() {
            subscriber = nil
        }
    }
}
#endif
