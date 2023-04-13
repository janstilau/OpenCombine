// A publisher that exposes a method for outside callers to publish elements.
// 一个, 外界可以通过 API 来手动进行信号发送的 ObjectPublisher. 这个类型, 在 Combine 中使用的很广.
// 应该这样说, 要么是用 Future, 要么使用 subject. 这是自定义 Publisher 的两个非常重要的方法.

/// A subject is a publisher that you can use to ”inject” values into a stream, by calling
/// its `send()` method. This can be useful for adapting existing imperative code to the
/// Combine model.

/*
 所有的 Subject, 都是使用的 class 进行的实现.
 这是很重要的, 因为, Subject 作为分发器, 是不可能是一个值语义的对象的.
 */

// Subject 天然是一个 Publisher, 这里新添加的一些方法, 都是用来手动控制 Subject 发送数据.
public protocol Subject: AnyObject, Publisher {
    /// Sends a value to the subscriber.
    ///
    /// - Parameter value: The value to send.
    func send(_ value: Output)
    
    /// Sends a completion signal to the subscriber.
    ///
    /// - Parameter completion: A `Completion` instance which indicates whether publishing
    ///   has finished normally or failed with an error.
    func send(completion: Subscribers.Completion<Failure>)
    
    /// Sends a subscription to the subscriber.
    /// This call provides the `Subject` an opportunity to establish demand for any new
    /// upstream subscriptions.
    /// - Parameter subscription: The subscription instance through which the subscriber
    ///   can request elements.
    // 目前仅仅是在 Subject 当做 Subscriber 的时候, 会调用到该方法.
    // 也就是说, 
    func send(subscription: Subscription)
}

/*
 Void 在 Swfit 里面, 是一个非常关键的类型. 他表示的就是, 事件发生了, 但是不会有相关的数据.
 */
extension Subject where Output == Void {
    /// Sends a void value to the subscriber.
    /// Use `Void` inputs and outputs when you want to signal that an event has occurred,
    /// but don’t need to send the event itself.
    public func send() {
        send(())
    }
}
