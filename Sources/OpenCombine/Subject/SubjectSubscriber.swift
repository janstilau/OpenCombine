
// 专门, 找了一个类型, 来包装 Subject.
// Subject 并不天然是 Subscriber, 所以不能直接被 Publisher 进行 Subscribe.

// 所以, 实际上是增加了一个节点, 这个节点里面, 包装了 Subject 对象. 而这个几点, 是用弱引用的方式, 包装的 Subject 对象.
// 所以, Subject 的声明周期, 其实是不受这个响应联调的影响的.


internal final class SubjectSubscriber<Downstream: Subject>
: Subscriber,
  Subscription,
  CustomStringConvertible,
  CustomReflectable,
  CustomPlaygroundDisplayConvertible {
    
    private let lock = UnfairLock.allocate()
    
    // 记录下游 Subject 节点.
    // 这是一个弱引用, 所以, 当 Subject 节点析构了之后, 上游节点, 是不会触发到下游的 Subject 的.
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
    
    internal func receive(subscription: Subscription) {
        lock.lock()
        guard upstreamSubscription == nil, let subject = downstreamSubject else {
            lock.unlock()
            return
        }
        // 记录上游节点. 这里会有循环引用.
        upstreamSubscription = subscription
        lock.unlock()
        // 然后把自己, 当做 Subject 的上游节点. Subject 在析构的时候, 会触发 self.cancel 方法, 通知上游节点, 进行 cancel.
        subject.send(subscription: self)
    }
    
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
        // 当, 收到上游节点的完成事件之后, 交给下游节点.
        // 然后主动释放资源. 其实感觉, 应该是上下游节点都释放. 不过, 因为是上游主动发送过来的 CompletionEvent, 所以应该是上游节点, 已经主动打破了循环引用才是.
        subject.send(completion: completion)
        downstreamSubject = nil
    }
    
    internal func request(_ demand: Subscribers.Demand) {
        lock.lock()
        guard let subscription = upstreamSubscription else {
            lock.unlock()
            return
        }
        lock.unlock()
        subscription.request(demand)
    }
    
    internal func cancel() {
        lock.lock()
        guard !isCancelled,
                let subscription = upstreamSubscription else {
            lock.unlock()
            return
        }
        // 上游资源的释放, 是打破和上游资源一起构成的循环引用
        upstreamSubscription = nil
        // 下游资源的示范, 是打破下游资源一起构成的循环引用
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
