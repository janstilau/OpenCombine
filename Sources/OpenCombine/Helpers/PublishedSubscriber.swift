
/*
 在 Combine 中, Subject 并不是一个 Subscriber.
 Subject 协议里面的各个方法, 其实是和自己的抽象相关的, 并没有主动向 Subscriber 进行靠拢.
 所以, 是不能直接将 Subject 添加到 receive 的函数后面的.
 所以, 在 Combine 中, 要专门写一个中介类型, 来完成这件事.
 */
internal struct PublishedSubscriber<Value>: Subscriber {
    
    internal typealias Input = Value
    
    internal typealias Failure = Never
    
    internal let combineIdentifier = CombineIdentifier()
    
    // 因为这里是 weak, 所以, Subject 消亡之后, 这里自动就没有引用了.
    private weak var subject: PublishedSubject<Value>?
    
    internal init(_ subject: PublishedSubject<Value>) {
        self.subject = subject
    }
    
    // 就是调用 Subject 的抽象. 不太明白, 为什么不主动进行 Subscriber 的靠拢.
    internal func receive(subscription: Subscription) {
        subject?.send(subscription: subscription)
    }
    
    internal func receive(_ input: Value) -> Subscribers.Demand {
        subject?.send(input)
        return .none
    }
    
    internal func receive(completion: Subscribers.Completion<Never>) {}
}
