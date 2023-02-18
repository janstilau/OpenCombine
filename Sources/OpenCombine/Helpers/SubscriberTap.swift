//
//  SubscriberTap.swift
//  
//
//  Created by Sergej Jaskiewicz on 27.09.2020.
//

internal protocol SubscriberTapMarker {
    var inner: Any { mutating get }
}

// Debug 相关的东西. 
internal struct SubscriberTap<Subscriber: OpenCombine.Subscriber>
: OpenCombine.Subscriber,
  CustomStringConvertible,
  SubscriberTapMarker
{
    internal typealias Input = Subscriber.Input
    
    internal typealias Failure = Subscriber.Failure
    
    private let subscriber: Subscriber
    
    // 这是一个 Lazy 的.
    internal lazy var inner: Any = AnySubscriber(self.subscriber)
    
    internal init(subscriber: Subscriber) {
        self.subscriber = subscriber
    }
    
    internal var combineIdentifier: CombineIdentifier {
        return subscriber.combineIdentifier
    }
    
    internal func receive(subscription: Subscription) {
        let hook = DebugHook.getGlobalHook()
        // 不太明白为什么, 会收到 SubscriptionTap 的中间节点.
        if let subscriptionTap = subscription as? SubscriptionTap {
            hook?.willReceive(subscriber: subscriber,
                              subscription: subscriptionTap.subscription)
            subscriber.receive(subscription: subscriptionTap)
            hook?.didReceive(subscriber: subscriber,
                             subscription: subscriptionTap.subscription)
        } else {
            hook?.willReceive(subscriber: subscriber, subscription: subscription)
            // SubscriberTap 里面, 接收到上游 Subscription, 主动的包装一下 SubscriptionTap
            subscriber
                .receive(subscription: SubscriptionTap(subscription: subscription))
            hook?.didReceive(subscriber: subscriber, subscription: subscription)
        }
    }
    
    internal func receive(_ input: Input) -> Subscribers.Demand {
        let hook = DebugHook.getGlobalHook()
        hook?.willReceive(subscriber: subscriber, input: input)
        let newDemand = subscriber.receive(input)
        hook?.didReceive(subscriber: subscriber,
                         input: input,
                         resultingDemand: newDemand)
        return newDemand
    }
    
    internal func receive(completion: Subscribers.Completion<Subscriber.Failure>) {
        let hook = DebugHook.getGlobalHook()
        hook?.willReceive(subscriber: subscriber, completion: completion)
        subscriber.receive(completion: completion)
        hook?.didReceive(subscriber: subscriber, completion: completion)
    }
    
    internal var description: String {
        return String(describing: subscriber)
    }
}
