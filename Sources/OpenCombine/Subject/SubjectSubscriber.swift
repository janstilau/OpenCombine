/*
 Subject 并不天然是一个 Subscriber, 每次使用 Publisher receive 一个 Subject 的时候, 其实都是用下面的类型, 进行了一次包装.
 */
// SubjectSubscriber 并不关心, 具体的 Subject 是什么类型. 这里使用的泛型.
// 这里不能用 Protocol 进行存储, 因为在 Publisher 类型里面, associatedtype Output, 是有着关联类型的.
// 所以, 实际上 SubjectSubscriber 在真正被使用的时候, 还是有着类型信息在里面的.
internal final class SubjectSubscriber<Downstream: Subject>
: Subscriber,
  Subscription,
  CustomStringConvertible,
  CustomReflectable,
  CustomPlaygroundDisplayConvertible {
    
    private let lock = UnfairLock.allocate()
    
    // 记录下游 Subject 节点.
    // 这是一个弱引用, 所以, 当 Subject 节点析构了之后, 上游节点, 是不会触发到下游的 Subject 的.
    // 这符合了 Combine 里面, 最后的一个节点数据, 自动是 cancel 的通用设计.
    private weak var downstreamSubject: Downstream?
    // 记录上游 Subscription 节点. 这是惯例的实现, 和上游节点, 形成的了循环引用的关系.
    private var upstreamSubscription: Subscription?
    
    private var isCancelled: Bool { return downstreamSubject == nil }
    
    internal init(_ parent: Downstream) {
        self.downstreamSubject = parent
    }
    
    deinit {
        lock.deallocate()
    }
    
    /*
     对于 Subject 来说, 它是在外部创建的, 所以没有办法去限制, Subject 被当做 Subscriber 的次数的.
     一个 Subject, 可以作为多方的终点, 同时, 又是多方的起点.
     所以, 在 Subject 的内部, 是存储的多方的来源和多方去处的. 正是因为有着这样的一套机制, 才使得 Subject 是 multicast 内部的真正实现.
     */
    internal func receive(subscription: Subscription) {
        lock.lock()
        guard upstreamSubscription == nil, let subject = downstreamSubject else {
            lock.unlock()
            return
        }
        
        // 记录上游节点. 这里会有循环引用.
        upstreamSubscription = subscription
        lock.unlock()
        
        // 这是在库里面, 唯一的一个 Subject 调用 send(subscription 的场景.
        // Subject, 对于上游其实是 unlimited Demand 管理的.
        subject.send(subscription: self)
    }
    
    // 收到上游的事件数据, 透传到 subject 中.
    internal func receive(_ input: Downstream.Output) -> Subscribers.Demand {
        lock.lock()
        guard let subject = downstreamSubject, upstreamSubscription != nil else {
            lock.unlock()
            return .none
        }
        lock.unlock()
        // 当前节点收到上游节点的数据的时候, 是直接转交给了存储的 subject 节点.
        subject.send(input)
        return .none
    }
    
    internal func receive(completion: Subscribers.Completion<Downstream.Failure>) {
        lock.lock()
        guard let subject = downstreamSubject, upstreamSubscription != nil else {
            lock.unlock()
            return
        }
        lock.unlock()
        // 直接把结束事件, 给到链接的 Subject 对象.
        // 因为这是一个结束的事件, 所以, 应该在方法内, 做资源的回收工作.
        subject.send(completion: completion)
        downstreamSubject = nil
    }
    
    internal func request(_ demand: Subscribers.Demand) {
        lock.lock()
        guard let savedSubscription = upstreamSubscription else {
            lock.unlock()
            return
        }
        lock.unlock()
        // 使用存储的上游节点, 来请求 Demand
        savedSubscription.request(demand)
    }
    
    internal func cancel() {
        lock.lock()
        guard !isCancelled, let subscription = upstreamSubscription else {
            lock.unlock()
            return
        }
        
        // 上游资源的释放, 是打破和上游资源一起构成的循环引用
        upstreamSubscription = nil
        downstreamSubject = nil
        lock.unlock()
        // 然后触发上游资源的 cancel.
        subscription.cancel()
    }
    
    
    
    
    internal var description: String { return "Subject" }
    
    internal var playgroundDescription: Any { return description }
    
    internal var customMirror: Mirror {
        let children: [Mirror.Child] = [
            ("downstreamSubject", downstreamSubject as Any),
            ("upstreamSubscription", upstreamSubscription as Any),
            ("subject", downstreamSubject as Any)
        ]
        return Mirror(self, children: children)
    }
}
