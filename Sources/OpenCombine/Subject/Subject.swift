/// A publisher that exposes a method for outside callers to publish elements.
// 一个, 外界可以通过 API 来手动进行信号发送的 ObjectPublisher. 这个类型, 在 Combine 中使用的很广.

/// A subject is a publisher that you can use to ”inject” values into a stream, by calling
/// its `send()` method. This can be useful for adapting existing imperative code to the
/// Combine model.

// 虽然上面这样说, 但是看源码, 很多地方都进行了 Inner 节点的自定义.
// 其中, 非常关键的一点就是, request Demand 的管理. 在 Combine 的 Pull 模型下, 是需要下游节点明确的 Request 之后, Publisher 才主动地进行信号创建逻辑的触发的. 这单纯的使用 Subject 类型的包装, 是达不到该目的的.

// 注意, Combine 中的 Subject, 仅仅是一个 Publisher, 并不是一个 Subscriber.
// 如果是使用 Subject 当做 Subscriber, 其实是使用了一个包装类型-SubjectSubscriber, 在里面, 是使用一个弱指针, 来指引着 Subject 对象.
// 如果 Subject 对象 deinit 了, 弱指针为 nil. 这个响应链条也就断了.
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
