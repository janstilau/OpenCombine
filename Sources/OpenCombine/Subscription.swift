
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

/// 代表订阅者连接到发布者的连接的协议。
///
/// 订阅是有类约束的，因为 Subscription 具有身份 - 定义了特定订阅者连接到发布者的时刻。
/// 取消 Subscription 必须是线程安全的。
///
/// 您只能取消一次 Subscription。
///
/// 取消订阅会释放通过连接到 Subscriber 时先前分配的任何资源
public protocol Subscription: Cancellable, CustomCombineIdentifierConvertible {

    /// Tells a publisher that it may send more values to the subscriber.
    func request(_ demand: Subscribers.Demand)
}
