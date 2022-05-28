
// A publisher that exposes a method for outside callers to publish elements.
// 一个, 外界可以通过 API 来手动进行信号发送的 ObjectPublisher. 这个类型, 在 Combine 中使用的很广.

/// A subject is a publisher that you can use to ”inject” values into a stream, by calling
/// its `send()` method. This can be useful for adapting existing imperative code to the
/// Combine model.

// 注意, Combine 中的 Subject, 仅仅是一个 Publisher, 并不是一个 Subscriber.
// 如果是使用 Subject 当做 Subscriber, 其实是使用了一个包装类型-SubjectSubscriber, 在里面, 是使用一个弱指针, 来指引着 Subject 对象.

/*
 所有的 Subject, 都是使用的 class 进行的实现.
 这是很重要的, 因为, Subject 作为分发器, 是不可能是一个值语义的对象的.
 */
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
    
    // 这是, 命令式触发结束事件的基础. 在照片合成的那个例子里面, 就是在 ImagePicker 的 ViewDidDisappear 里面, 主动地触发了一次 Subject 的结束事件.
    func send(completion: Subscribers.Completion<Failure>)
    
    /// Sends a subscription to the subscriber.
    /// This call provides the `Subject` an opportunity to establish demand for any new
    /// upstream subscriptions.
    /// - Parameter subscription: The subscription instance through which the subscriber
    ///   can request elements.
    /*
     目前, 该方法仅仅在 SubjectSubscriber, PublishedSubscriber 中被使用到了.
     Subject 并不是一个 Subscriber. 是进行了一层包装. 就是上面的两个类.
     上面的两个类,
     */
    func send(subscription: Subscription)
}

extension Subject where Output == Void {
    /// Sends a void value to the subscriber.
    /// Use `Void` inputs and outputs when you want to signal that an event has occurred,
    /// but don’t need to send the event itself.
    // 这是一个简便的做法, 如果 Output 是 Void 的话, 那么直接调用 send, 封装一下 send(_ value: Output) 的调用
    public func send() {
        send(())
    }
}
