/// A publisher that exposes a method for outside callers to publish elements.
// 一个, 外界可以通过 API 来手动进行信号发送的 ObjectPublisher. 这个类型, 在 Combine 中使用的很广.
// 在 Combine 里面, 没有提供 Create 函数来自定义 Publisher, 而是, 通过 Subject 对象, 来完成相应的指令代码触发信号的操作.

/// A subject is a publisher that you can use to ”inject” values into a stream, by calling
/// its `send()` method. This can be useful for adapting existing imperative code to the
/// Combine model.

/*
 和 Rx 的版本, 没有太大的区别. 主要用来进行命令式到响应式的切换的.
 不过, 同 Rx 大量使用 Subject 作为成员变量不同的是, 在 Combine 里面, 是大量使用了 @PropertyWrapper 这种技术.
 */

// 注意, Combine 中的 Subject, 仅仅是一个 Publisher, 并不是一个 Subscriber.
public protocol Subject: AnyObject, Publisher {
    
    /// Sends a value to the subscriber.
    ///
    /// - Parameter value: The value to send.
    
    // 这是, 命令式的代码触发信号发送的基础. 
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
    //
    func send(subscription: Subscription)
}

extension Subject where Output == Void {
    
    /// Sends a void value to the subscriber.
    ///
    /// Use `Void` inputs and outputs when you want to signal that an event has occurred,
    /// but don’t need to send the event itself.
    // 这是一个简便的做法, 如果 Output 是 Void 的话, 那么直接调用 send, 封装一下 send(_ value: Output) 的调用
    public func send() {
        send(())
    }
}
