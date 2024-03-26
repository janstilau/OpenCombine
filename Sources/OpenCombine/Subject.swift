/// A publisher that exposes a method for outside callers to publish elements.
///
/// A subject is a publisher that you can use to ”inject” values into a stream, by calling
/// its `send()` method. This can be useful for adapting existing imperative code to the
/// Combine model.

/*
 Subject 其实就是一个 Publisher, 只不过可以用来主动地进行数据的发送.
 send, send(completion
 */

/// 一个发布者，公开了一个供外部调用者发布元素的方法。
///
/// 主题是一个您可以使用其 send() 方法来“注入”值到流中的发布者。这对于将现有的命令式代码适应为Combine模型非常有用。
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
    ///
    /// This call provides the `Subject` an opportunity to establish demand for any new
    /// upstream subscriptions.
    ///
    /// - Parameter subscription: The subscription instance through which the subscriber
    ///   can request elements.
    // 这个只会在 SubjectSubscriber 里面使用到了. 
    func send(subscription: Subscription)
}

extension Subject where Output == Void {

    /// Sends a void value to the subscriber.
    ///
    /// Use `Void` inputs and outputs when you want to signal that an event has occurred,
    /// but don’t need to send the event itself.
    public func send() {
        send(())
    }
}
