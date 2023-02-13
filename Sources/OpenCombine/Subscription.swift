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

// 这个可以认为是响应链条的节点了. 
public protocol Subscription: Cancellable, CustomCombineIdentifierConvertible {
    
    /// Tells a publisher that it may send more values to the subscriber.
    // 数据的传递动作, 还是要交给 Subscriber 来进行处理.
    // Subscription 这里承担的责任, 因该是可以进行 demand 的传输. 
    func request(_ demand: Subscribers.Demand)
}
