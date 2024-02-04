/*
 可以认为是, 简化版本的 SubjectSubscriber
 不用实现 Subscription 的语义.
 */
internal struct PublishedSubscriber<Value>: Subscriber {

    internal typealias Input = Value

    internal typealias Failure = Never

    internal let combineIdentifier = CombineIdentifier()

    // 这里是一个弱引用. 
    private weak var subject: PublishedSubject<Value>?

    internal init(_ subject: PublishedSubject<Value>) {
        self.subject = subject
    }

    // 直接把 Subscription 透传到了 subject 对象上.
    internal func receive(subscription: Subscription) {
        subject?.send(subscription: subscription)
    }

    // 直接把 value, 透传到了 subject 对象上. 
    internal func receive(_ input: Value) -> Subscribers.Demand {
        subject?.send(input)
        return .none
    }

    internal func receive(completion: Subscribers.Completion<Never>) {}
}

/*
 internal final class SubjectSubscriber<Downstream: Subject>
     : Subscriber,
       CustomStringConvertible,
       CustomReflectable,
       CustomPlaygroundDisplayConvertible,
       Subscription
 {
     private let lock = UnfairLock.allocate()
     
     // 这里是弱引用. Subject 的生命周期, 不收到这里的控制.
     private weak var downstreamSubject: Downstream?
     private var upstreamSubscription: Subscription?

     private var isCancelled: Bool { return downstreamSubject == nil }

     internal init(_ parent: Downstream) {
         self.downstreamSubject = parent
     }

     deinit {
         lock.deallocate()
     }

     // 上游的 Subscription 到来了, 对上游的 Subscription 进行强引用.
     // 然后自己当做了下游 Subject 的上游.
     // subject, 想要收到 Subscription, 只会在这个场景下.
     // 也就是, 当 Subject 当做了节点的下游.
     internal func receive(subscription: Subscription) {
         lock.lock()
         guard upstreamSubscription == nil, let subject = downstreamSubject else {
             lock.unlock()
             return
         }
         upstreamSubscription = subscription
         lock.unlock()
         
         subject.send(subscription: self)
     }

     // 收到了上游的数据, 将数据交给下游.
     internal func receive(_ input: Downstream.Output) -> Subscribers.Demand {
         lock.lock()
         guard let subject = downstreamSubject, upstreamSubscription != nil else {
             lock.unlock()
             return .none
         }
         lock.unlock()
         // 交给下游, 就是使用 Subject 的 send, 将数据交给 Subject, 由 Subject 进行分发.
         // 实际上, Subject 没有实现  receive(_ input: Downstream.Output) 方法.
         // 在 SubjectSubscriber 这个包装器里面, 也是使用了 send 来进行上游数据传递到了 Subject 里面.
         subject.send(input)
         return .none
     }

     // 收到了上游的结束事件, 将事件传递给了下游.
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

     // 向上游, 传递 Demand 的需求.
     internal func request(_ demand: Subscribers.Demand) {
         lock.lock()
         guard let subscription = upstreamSubscription else {
             lock.unlock()
             return
         }
         lock.unlock()
         subscription.request(demand)
     }

     // 向上游, 传递 Cancel 的需求. 并且将相关的引用进行切断. 完成内存的释放 .
     internal func cancel() {
         lock.lock()
         guard !isCancelled, let subscription = upstreamSubscription else {
             lock.unlock()
             return
         }
         upstreamSubscription = nil
         downstreamSubject = nil
         lock.unlock()
         // 上游的 subscription 进行 cancel.
         subscription.cancel()
     }
 }
 */
