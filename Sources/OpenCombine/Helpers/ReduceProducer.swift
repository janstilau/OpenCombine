
/// A helper class that acts like both subscriber and subscription.
///
/// Reduce-like operators send an instance of their `Inner` class that is subclass
/// of this class to the upstream publisher (as subscriber) and
/// to the downstream subscriber (as subscription).
///
/// Reduce-like operators include `Publishers.Reduce`, `Publishers.TryReduce`,
/// `Publishers.Count`, `Publishers.FirstWhere`, `Publishers.AllSatisfy` and more.
///
/// Subclasses must override the `receive(newValue:)` and `description`.
///
/// 充当订阅者和订阅的辅助类。
///
/// 类似于 `reduce` 的操作符向上游发布者（作为订阅者）和向下游订阅者（作为订阅）发送其 `Inner` 类的实例，
/// 该类是此类的子类。
///
/// 类似于 `reduce` 的操作符包括 `Publishers.Reduce`、`Publishers.TryReduce`、`Publishers.Count`、
/// `Publishers.FirstWhere`、`Publishers.AllSatisfy` 等等。
///
/// 子类必须重写 `receive(newValue:)` 和 `description`。

// Reduce, 一系列的值, 变为一个值的过程.
internal class ReduceProducer<Downstream: Subscriber,
                              Input,
                              Output,
                              UpstreamFailure: Error,
                              Reducer>
// Reducer 是一个闭包.
: CustomStringConvertible,
  CustomReflectable
where Downstream.Input == Output
{
    // NOTE: This class has been audited for thread safety
    
    // MARK: - State
    
    internal final var result: Output?
    
    private let initial: Output?
    
    internal final let reduce: Reducer
    
    private var status = SubscriptionStatus.awaitingSubscription
    
    private let downstream: Downstream
    
    private let lock = UnfairLock.allocate()
    
    private var downstreamRequested = false
    
    private var cancelled = false
    
    private var completed = false
    
    private var upstreamCompleted = false
    
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
    
    // 重构点.
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
    
    // MARK: -
}

extension ReduceProducer: Subscriber {
    // 惯例实现.
    internal func receive(subscription: Subscription) {
        lock.lock()
        guard case .awaitingSubscription = status else {
            lock.unlock()
            subscription.cancel()
            return
        }
        status = .subscribed(subscription)
        lock.unlock()
        downstream.receive(subscription: self)
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
        switch self.receive(newValue: input) {
        case .continue:
            break
        case .finished:
            lock.lock()
            upstreamCompleted = true
            let downstreamRequested = self.downstreamRequested
            if downstreamRequested {
                completed = true
            }
            status = .terminal
            let result = self.result
            lock.unlock()
            
            subscription.cancel()
            
            guard downstreamRequested else { break }
            
            sendResultAndFinish(result)
        case let .failure(error):
            lock.lock()
            upstreamCompleted = true
            completed = true
            status = .terminal
            lock.unlock()
            
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
