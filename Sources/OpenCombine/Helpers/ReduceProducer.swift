
/// A helper class that acts like both subscriber and subscription.

/// Reduce-like operators send an instance of their `Inner` class that is subclass
/// of this class to the upstream publisher (as subscriber) and
/// to the downstream subscriber (as subscription).

/// Reduce-like operators include
/// `Publishers.Reduce`,
/// `Publishers.TryReduce`,
/// `Publishers.Count`,
/// `Publishers.FirstWhere`,
/// `Publishers.AllSatisfy` and more.
///
/// Subclasses must override the `receive(newValue:)` and `description`.

internal class ReduceProducer<Downstream: Subscriber,
                              Input,
                              Output,
                              UpstreamFailure: Error,
                              // Reducer 是一个闭包.
                              Reducer>
: CustomStringConvertible,
  CustomReflectable
where Downstream.Input == Output
{
    // NOTE: This class has been audited for thread safety
    
    // MARK: - State
    
    // 结束值.
    internal final var result: Output?
    
    // 起始值.
    private let initial: Output?
    
    // 闭包.
    internal final let reduce: Reducer
    
    // 这个状态, 在所有的 Subscriber 里面, 都会有.
    private var status = SubscriptionStatus.awaitingSubscription
    
    // 作为, 一个 Subscription, 应该有 downstream 这个数据.
    private let downstream: Downstream
    
    private let lock = UnfairLock.allocate()

    // 如果, 下游节点调用了 RequestDemand, 这个值会设置为 True.
    private var downstreamRequested = false
    // 如果, 上游节点发送了 Complete 事件, 这个值会设置为 True.
    private var upstreamCompleted = false
    // 因为 Combine 是 Pull 的机制, 所以只有上面的两个值都是 true 的时候, 才会真正向后方发送数据.
    
    private var cancelled = false
    
    private var completed = false
    
    internal init(downstream: Downstream, initial: Output?, reduce: Reducer) {
        self.downstream = downstream
        self.initial = initial
        self.result = initial
        self.reduce = reduce
    }
    
    deinit {
        lock.deallocate()
    }
    
    // MARK: - Abstract methods
    
    internal func receive(
        newValue: Input
    ) -> PartialCompletion<Void, Downstream.Failure> {
        abstractMethod()
    }
    
    internal var description: String {
        abstractMethod()
    }
    
    // MARK: - CustomReflectable
    
    internal var customMirror: Mirror {
        lock.lock()
        defer { lock.unlock() }
        
        let children: [Mirror.Child] = [
            ("downstream", downstream),
            ("result", result as Any),
            ("initial", initial as Any),
            ("status", status)
        ]
        return Mirror(self, children: children)
    }
    
    // MARK: - Private
    
    /// - Precondition: `lock` is held.
    private func receiveFinished() {
        guard !cancelled, !completed, !upstreamCompleted else {
            lock.unlock()
            // This should never happen, because `receive(completion:)`
            // (from which this function is called) early exists if
            // `status` is `.terminal`.
            assertionFailure("The subscription should have been terminated by now")
            return
        }
        upstreamCompleted = true
        if downstreamRequested {
            self.completed = true
        }
        let completed = self.completed
        let result = self.result
        lock.unlock()
        
        if completed {
            sendResultAndFinish(result)
        }
    }
    
    /// - Precondition: `lock` is held.
    private func receiveFailure(_ failure: UpstreamFailure) {
        guard !cancelled, !completed, !upstreamCompleted else {
            lock.unlock()
            // This should never happen, because `receive(completion:)`
            // (from which this function is called) early exists if
            // `status` is `.terminal`.
            assertionFailure("The subscription should have been terminated by now")
            return
        }
        upstreamCompleted = true
        completed = true
        lock.unlock()
        downstream.receive(completion: .failure(failure as! Downstream.Failure))
    }
    
    private func sendResultAndFinish(_ result: Output?) {
        assert(completed && upstreamCompleted)
        if let result = result {
            _ = downstream.receive(result)
        }
        downstream.receive(completion: .finished)
    }
}

// 能够充当 Subscriber, 就是能够在响应者链路中, 作为上游节点的后续节点.
extension ReduceProducer: Subscriber {
    
    internal func receive(subscription: Subscription) {
        lock.lock()
        guard case .awaitingSubscription = status else {
            lock.unlock()
            subscription.cancel()
            return
        }
        status = .subscribed(subscription)
        lock.unlock()
        // 自己, 作为 subscription, 接受下游节点的 RequestDemand, Cancel 请求.
        downstream.receive(subscription: self)
        // 自己, 作为 Subscriber, 要求上游节点发送数据, 尽量多发.
        subscription.request(.unlimited)
    }
    
    internal func receive(_ input: Input) -> Subscribers.Demand {
        lock.lock()
        guard case let .subscribed(subscription) = status else {
            lock.unlock()
            return .none
        }
        lock.unlock()
        
        // Combine doesn't hold the lock when calling `receive(newValue:)`.
        //
        // This can lead to data races if the contract is violated
        // (like when we receive input from multiple threads simultaneously).
        
        // 根据, 子类的 receive(newValue 的实现, 来影响 receive(_ input: Input) -> Subscribers.Demand 的实现.
        switch self.receive(newValue: input) {
        case .continue:
            break
        case .finished:
            lock.lock()
            upstreamCompleted = true
            let downstreamRequested = self.downstreamRequested
            if downstreamRequested {
                // 根据, upstreamCompleted downstreamRequested 共同过来决定 Complete 的状态.
                completed = true
            }
            // 自身的状态改变. 不会在接受响应中的各种事件.
            status = .terminal
            let result = self.result
            lock.unlock()
            // 取消对于上游节点的注册.
            subscription.cancel()
            guard downstreamRequested else { break }
            // 验证, 如果可以给下游节点发送消息, 发送存储的 Result 的值.
            sendResultAndFinish(result)
        case let .failure(error):
            lock.lock()
            upstreamCompleted = true
            completed = true
            status = .terminal
            lock.unlock()
            // 发生了错误, 直接给后续节点, 发送事件.
            subscription.cancel()
            downstream.receive(completion: .failure(error))
        }
        
        return .none
    }
    
    internal func receive(completion: Subscribers.Completion<UpstreamFailure>) {
        lock.lock()
        guard case .subscribed = status else {
            lock.unlock()
            return
        }
        status = .terminal
        switch completion {
        case .finished:
            receiveFinished()
        case let .failure(error):
            receiveFailure(error)
        }
    }
}

extension ReduceProducer: Subscription {
    
    internal func request(_ demand: Subscribers.Demand) {
        demand.assertNonZero()
        lock.lock()
        guard !downstreamRequested, !cancelled, !completed else {
            lock.unlock()
            return
        }
        downstreamRequested = true
        
        guard upstreamCompleted else  {
            lock.unlock()
            return
        }
        // 如果, upstreamCompleted && downstreamRequested, 就将自己的 Request 值, 发送给后方节点, 发送给后方节点的 Complete 事件.
        completed = true
        let result = self.result
        lock.unlock()
        sendResultAndFinish(result)
    }
    
    internal func cancel() {
        lock.lock()
        guard case let .subscribed(subscription) = status else {
            lock.unlock()
            return
        }
        cancelled = true
        status = .terminal
        lock.unlock()
        subscription.cancel()
    }
}

extension ReduceProducer: CustomPlaygroundDisplayConvertible {
    internal var playgroundDescription: Any { return description }
}
