
// 专门, 找了一个类型, 来包装 Subject.
// Subject 并不天然是 Subscriber, 所以不能直接被 Publisher 进行 Subscribe.

// 所以, 实际上, 是在 Subject 前增加了一个节点, 使用这个节点, 来触发 Subject 的操作.

// 这里还有一层含义, 就是 Subject 并不是 cancellable 的, 这个节点, 也是也是 Subs cription. 真正使用者进行整个链条的 cancel 的时候, 其实是由这个对象进行的触发.
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
    // 记录上游 Subscription 节点.
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
        // 然后把自己, 当做 Subject 的上游节点.
        subject.send(subscription: self)
    }
    
    internal func receive(_ input: Downstream.Output) -> Subscribers.Demand {
        lock.lock()
        guard let subject = downstreamSubject, upstreamSubscription != nil else {
                  lock.unlock()
                  return .none
              }
        lock.unlock()
        // 交给 Subject 进行分发.
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
        guard !isCancelled, let subscription = upstreamSubscription else {
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
