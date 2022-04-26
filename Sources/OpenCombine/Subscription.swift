//
//  Subscription.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A protocol representing the connection of a subscriber to a publisher.
///
/// Subscriptions are class constrained because a `Subscription` has identity -
/// defined by the moment in time a particular subscriber attached to a publisher.
/// Canceling a `Subscription` must be thread-safe.
///
/// You can only cancel a `Subscription` once.
///
/// Canceling a subscription frees up any resources previously allocated by attaching
/// the `Subscriber`.

public protocol Subscription: Cancellable, CustomCombineIdentifierConvertible {
    
    /// Tells a publisher that it may send more values to the subscriber.
    func request(_ demand: Subscribers.Demand)
}

/*
 Subscription
 
 在 Rx 里面, Sink 是真正的节点. Publisher 的 Subscribe 中, 会创建真正的 Sink 对象, 串联出响应链条出来.
 
 在 Combine 的这个实现里面, Subscribption 是真正的节点. Publisher 在 receive 中, 会创建各个 Publisher 的 Inner 对象, 上级的 Inner 对象, 会作为下级的 Subscription 对象, 传递过去.
 在搭建完响应链条之后, func request(_ demand: Subscribers.Demand) 
 */
