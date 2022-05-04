
// @Publish 中的 Subject 的 包装类.
// 这是一个专门的包装类型, 专门给 PublishedSubject 使用的.
// 他和 SubjectSubscriber 的区别, 就是不会出现, Complete 事件的发生.
internal struct PublishedSubscriber<Value>: Subscriber {
    
    internal typealias Input = Value
    
    internal typealias Failure = Never
    
    internal let combineIdentifier = CombineIdentifier()
    
    // 因为这里是 weak, 所以, Subject 消亡之后, 这里自动就没有引用了.
    private weak var subject: PublishedSubject<Value>?
    
    internal init(_ subject: PublishedSubject<Value>) {
        self.subject = subject
    }
    
    // 所有的 Subscriber 的实现, 都是调用 subject 方法完成的.
    // 这也就是唯一的 send(subscription 的调用的场景.
    // 我们在使用 Subject 的时候, 其实是习惯于自己使用 receive(_ input: Value), receive(completion, 来做 Subject 信号发送的自我控制的.
    // 只有, Subject 在链条内的时候, 才会触发他上游节点的传递. 这个时候, 就需要使用到该方法了. 
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
