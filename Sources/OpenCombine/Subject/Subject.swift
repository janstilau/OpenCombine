/*
 Combine
 Customize handling of asynchronous events by combining event-processing operators.
 
 Overview
 The Combine framework provides a declarative Swift API for processing values over time. These values can represent many kinds of asynchronous events.
 Combine declares publishers to expose values that can change over time, and subscribers to receive those values from the publishers.
 
 The Publisher protocol declares a type that can deliver a sequence of values over time. Publishers have operators to act on the values received from upstream publishers and republish them.
 这个说的很清楚, Operattor 的作用, 是接收上游的数据, 加工, 然后 Publish 给下游.
 
 At the end of a chain of publishers, a Subscriber acts on elements as it receives them. Publishers only emit values when explicitly requested to do so by subscribers. This puts your subscriber code in control of how fast it receives events from the publishers it’s connected to.
 这里说的很清楚, 被压的管理, 是Subsciber 的责任. 应该说, Operator 是不需要考虑被压管理的. 它仅仅是进行透传.
 
 Several Foundation types expose their functionality through publishers, including Timer, NotificationCenter, and URLSession. Combine also provides a built-in publisher for any property that’s compliant with Key-Value Observing.
 
 非常重要的就是在这里, 可以进行多个信号的连接操作.
 You can combine the output of multiple publishers and coordinate their interaction. For example, you can subscribe to updates from a text field’s publisher, and use the text to perform URL requests. You can then use another publisher to process the responses and use them to update your app.
 By adopting Combine, you’ll make your code easier to read and maintain, by centralizing your event-processing code and eliminating troublesome techniques like nested closures and convention-based callbacks.
 */


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
// Subject 天然是一个 Publisher, 它必须能够接收 Subscriber.
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
     */
    func send(subscription: Subscription)
}

/*
 Void 在 Swfit 里面, 是一个非常关键的类型. 他表示的就是, 事件发生了, 但是不会有相关的数据.
 */
extension Subject where Output == Void {
    /// Sends a void value to the subscriber.
    /// Use `Void` inputs and outputs when you want to signal that an event has occurred,
    /// but don’t need to send the event itself.
    // 这是一个简便的做法, 如果 Output 是 Void 的话, 那么直接调用 send, 封装一下 send(_ value: Output) 的调用
    public func send() {
        send(())
    }
}
