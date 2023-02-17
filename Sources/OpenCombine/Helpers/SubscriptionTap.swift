//
//  SubscriptionTap.swift
//  
//
//  Created by Sergej Jaskiewicz on 27.09.2020.
//

/*
 SubscriptionTap 是 Subscription 的包装器, 所有实际的 Subscription 的实现移交给自己保存的 Subscription.
 使用这个特殊的类型, 就是为了在里面, 触发 DebugHook 注册的各种机制. 
 */
internal struct SubscriptionTap: Subscription, CustomStringConvertible {
    
    internal let subscription: Subscription
    
    internal var combineIdentifier: CombineIdentifier {
        return subscription.combineIdentifier
    }
    
    internal func request(_ demand: Subscribers.Demand) {
        let hook = DebugHook.getGlobalHook()
        hook?.willRequest(subscription: subscription, demand: demand)
        subscription.request(demand)
        hook?.didRequest(subscription: subscription, demand: demand)
    }
    
    internal func cancel() {
        let hook = DebugHook.getGlobalHook()
        hook?.willCancel(subscription: subscription)
        subscription.cancel()
        hook?.didCancel(subscription: subscription)
    }
    
    internal var description: String {
        return String(describing: subscription)
    }
}
