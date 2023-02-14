internal struct PublishedSubscriber<Value>: Subscriber {
    
    internal typealias Input = Value
    
    internal typealias Failure = Never
    
    internal let combineIdentifier = CombineIdentifier()
    
    // 因为这里是 weak, 所以, Subject 消亡之后, 这里自动就没有引用了.
    private weak var subject: PublishedSubject<Value>?
    
    internal init(_ subject: PublishedSubject<Value>) {
        self.subject = subject
    }
    
    // 
    internal func receive(subscription: Subscription) {
        subject?.send(subscription: subscription)
    }
    
    internal func receive(_ input: Value) -> Subscribers.Demand {
        subject?.send(input)
        return .none
    }
    
    internal func receive(completion: Subscribers.Completion<Never>) {}
    // 这个类, 并不是一个 Subscription 的实现类. 因为, 对于 @published 的属性的 assign 是没有取消的使用场景的.
}
