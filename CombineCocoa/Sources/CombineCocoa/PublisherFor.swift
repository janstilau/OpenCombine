//
//  PublisherFor.swift
//  CombineCocoa
//
//  Created by liuguoqiang on 2024/4/1.
//

import Foundation
import Combine

/*
extension NSObject {
    func publisher<Value>(for keyPath: KeyPath<Self, Value>) -> AnyPublisher<Value, Never> where Value: AnyObject {
        return KeyValueObservingPublisher(object: self, keyPath: keyPath)
            .eraseToAnyPublisher()
    }
}

struct KeyValueObservingPublisher<Object: NSObject, Value: AnyObject>: Publisher {
    typealias Output = Value
    typealias Failure = Never

    private let object: Object
    private let keyPath: KeyPath<Object, Value>

    init(object: Object, keyPath: KeyPath<Object, Value>) {
        self.object = object
        self.keyPath = keyPath
    }

    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = KVOSubscription(subscriber: subscriber, object: object, keyPath: keyPath)
        subscriber.receive(subscription: subscription)
    }
}

private final class KVOSubscription<SubscriberType: Subscriber, Object: NSObject, Value: AnyObject>: Subscription where SubscriberType.Input == Value {
    private var subscriber: SubscriberType?
    private let observation: NSKeyValueObservation

 // KVO 里面, 触发 Emit 的逻辑. 而 Emit 里面, 就是进行值的读取然后发送.
 // 这里应该还把 cancel 实现了. 
    init(subscriber: SubscriberType, object: Object, keyPath: KeyPath<Object, Value>) {
        self.subscriber = subscriber
        self.observation = object.observe(keyPath, options: [.new]) { [weak self] (_, _) in
            self?.emitValue()
        }
    }

    func request(_ demand: Subscribers.Demand) {
        // KVO 不支持背压，所以我们忽略 demand
    }

    func cancel() {
        subscriber = nil
    }

    private func emitValue() {
        guard let subscriber = subscriber,
              let value = observation.object?.value(forKeyPath: observation.keyPath) as? Value else {
            return
        }

        _ = subscriber.receive(value)
    }
}

*/
